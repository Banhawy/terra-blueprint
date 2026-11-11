# -----------------------------------------------------------------------------
# queue-worker: background jobs pulled from a queue
#
#   producers -> SQS queue ──(after 3 failures)──> dead-letter queue
#                   │
#                   └─> EC2 Auto Scaling group (0..N, scales on queue depth)
#                         worker.py: receive -> process -> write S3 -> delete
#
# The group sits at zero instances while the queue is empty. Code ships from
# an S3 bucket; changing anything under worker/ rolls the instances.
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # Source files only: caches (__pycache__) would make the hash machine-dependent.
  code_files = toset([for f in fileset("${path.module}/worker", "**") : f if can(regex("\\.(py|txt)$", f)) && !strcontains(f, "__pycache__")])
  code_hash  = substr(sha256(join("", [for f in sort(local.code_files) : filesha256("${path.module}/worker/${f}")])), 0, 16)
  code_keys  = { for f in local.code_files : f => "${local.code_hash}/${f}" }

  alarm_actions = var.alarm_topic_arn == null ? [] : [var.alarm_topic_arn]
}

# --- Queues --------------------------------------------------------------------

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.name}-dlq"
  message_retention_seconds = 1209600 # 14 days, the maximum: time to investigate
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "jobs" {
  name                       = var.name
  visibility_timeout_seconds = var.job_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  receive_wait_time_seconds  = 20 # long polling
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.jobs.arn]
  })
}

# --- Buckets -------------------------------------------------------------------

module "results" {
  source = "../../components/s3"

  bucket_name   = "${var.name}-results-${local.account_id}"
  force_destroy = var.force_destroy
  lifecycle_rules = [{
    id              = "expire-results"
    expiration_days = var.results_retention_days
  }]
}

module "code" {
  source = "../../components/s3"

  bucket_name   = "${var.name}-code-${local.account_id}"
  force_destroy = true # contents are reproducible from this repository
  lifecycle_rules = [{
    id                                 = "expire-old-versions"
    noncurrent_version_expiration_days = 7
  }]
}

resource "aws_s3_object" "code" {
  for_each = local.code_keys

  bucket = module.code.bucket_name
  key    = each.value
  source = "${path.module}/worker/${each.key}"
  etag   = filemd5("${path.module}/worker/${each.key}")
}

# --- Instances -----------------------------------------------------------------

module "logs" {
  source = "../../components/cloudwatch/log-group"

  name              = "/ec2/${var.name}"
  retention_in_days = var.log_retention_in_days
}

module "workers" {
  source = "../../components/asg"

  name          = var.name
  vpc_id        = var.vpc_id
  subnet_ids    = var.private_subnet_ids
  instance_type = var.instance_type
  min_size      = 0
  max_size      = var.max_instances

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    aws_region           = data.aws_region.current.region
    queue_url            = aws_sqs_queue.jobs.url
    results_bucket       = module.results.bucket_name
    asg_name             = var.name
    log_group_name       = module.logs.name
    code_bucket          = module.code.bucket_name
    code_keys            = local.code_keys
    stop_timeout_seconds = var.job_timeout_seconds
  })

  depends_on = [aws_s3_object.code]
}

# --- Scaling on queue depth -----------------------------------------------------
# Add an instance while messages are waiting; remove one after 15 quiet minutes.
# Instances busy with a job are protected from scale-in by the worker itself.

module "scaling_alarms" {
  source = "../../components/cloudwatch/alarms"

  name_prefix = var.name

  alarms = {
    scale-out = {
      description         = "Messages are waiting: add a worker."
      namespace           = "AWS/SQS"
      metric_name         = "ApproximateNumberOfMessagesVisible"
      dimensions          = { QueueName = aws_sqs_queue.jobs.name }
      statistic           = "Maximum"
      period              = 60
      threshold           = var.scale_out_backlog
      comparison_operator = "GreaterThanOrEqualToThreshold"
      alarm_actions       = [module.workers.scale_out_policy_arn]
      ok_actions          = []
    }
    scale-in = {
      description         = "Queue has been empty for 15 minutes: remove a worker."
      namespace           = "AWS/SQS"
      metric_name         = "ApproximateNumberOfMessagesVisible"
      dimensions          = { QueueName = aws_sqs_queue.jobs.name }
      statistic           = "Maximum"
      period              = 300
      evaluation_periods  = 3
      threshold           = 0
      comparison_operator = "LessThanOrEqualToThreshold"
      # SQS stops publishing metrics for idle queues: treat silence as empty.
      treat_missing_data = "breaching"
      alarm_actions      = [module.workers.scale_in_policy_arn]
      ok_actions         = []
    }
  }
}

# --- Operational alarms ----------------------------------------------------------

module "alarms" {
  source = "../../components/cloudwatch/alarms"

  name_prefix           = var.name
  default_alarm_actions = local.alarm_actions
  default_ok_actions    = local.alarm_actions

  alarms = {
    dlq-not-empty = {
      description         = "Jobs failed ${var.max_receive_count} times and were dead-lettered. Inspect, fix, then redrive."
      namespace           = "AWS/SQS"
      metric_name         = "ApproximateNumberOfMessagesVisible"
      dimensions          = { QueueName = aws_sqs_queue.dlq.name }
      statistic           = "Maximum"
      threshold           = 0
      comparison_operator = "GreaterThanThreshold"
    }
    oldest-message-age = {
      description         = "The oldest job has waited more than ${var.alarm_oldest_message_age_seconds}s -- workers are stuck or at max capacity."
      namespace           = "AWS/SQS"
      metric_name         = "ApproximateAgeOfOldestMessage"
      dimensions          = { QueueName = aws_sqs_queue.jobs.name }
      statistic           = "Maximum"
      threshold           = var.alarm_oldest_message_age_seconds
      comparison_operator = "GreaterThanThreshold"
    }
    cpu-high = {
      description         = "Worker CPU above 90% for 15 minutes."
      namespace           = "AWS/EC2"
      metric_name         = "CPUUtilization"
      dimensions          = { AutoScalingGroupName = module.workers.asg_name }
      threshold           = 90
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 3
    }
  }
}
