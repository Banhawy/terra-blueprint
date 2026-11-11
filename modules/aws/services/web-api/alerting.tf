# -----------------------------------------------------------------------------
# Alerting
#
#   CloudWatch alarms ─┐
#                      ├─> SNS topic ─> notifier Lambda ─> chat webhook
#   EventBridge events ┘                (URL in Secrets Manager)
#
# Subscribe anything else (email, PagerDuty) to the same topic.
# -----------------------------------------------------------------------------

# Encrypting this topic with the AWS-managed aws/sns key would silently break
# delivery: CloudWatch alarms and EventBridge cannot use that key. Encryption
# would need a customer-managed key whose policy admits both services. The
# topic only ever carries alarm metadata.
#trivy:ignore:AVD-AWS-0095 -- see above; alarm metadata only.
resource "aws_sns_topic" "alerts" {
  name = "${var.name}-alerts"
}

data "aws_iam_policy_document" "alerts_topic" {
  statement {
    sid       = "AllowAlarmsAndEvents"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com", "events.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sns_topic_policy" "alerts" {
  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.alerts_topic.json
}

# --- Alarms --------------------------------------------------------------------

module "alarms" {
  source = "../../components/cloudwatch/alarms"

  name_prefix           = var.name
  default_alarm_actions = [aws_sns_topic.alerts.arn]
  default_ok_actions    = [aws_sns_topic.alerts.arn]

  alarms = {
    ecs-cpu-high = {
      description         = "Service CPU above ${var.alarm_cpu_threshold}% -- autoscaling is at its ceiling or tasks are undersized."
      namespace           = "AWS/ECS"
      metric_name         = "CPUUtilization"
      dimensions          = { ClusterName = module.app.cluster_name, ServiceName = module.app.service_name }
      threshold           = var.alarm_cpu_threshold
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 3
    }
    ecs-memory-high = {
      description         = "Service memory above ${var.alarm_memory_threshold}% -- risk of OOM kills."
      namespace           = "AWS/ECS"
      metric_name         = "MemoryUtilization"
      dimensions          = { ClusterName = module.app.cluster_name, ServiceName = module.app.service_name }
      threshold           = var.alarm_memory_threshold
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 3
    }
    alb-5xx = {
      description         = "The application returned more than ${var.alarm_5xx_threshold} 5xx responses in 5 minutes."
      namespace           = "AWS/ApplicationELB"
      metric_name         = "HTTPCode_Target_5XX_Count"
      dimensions          = { LoadBalancer = module.alb.arn_suffix, TargetGroup = aws_lb_target_group.app.arn_suffix }
      statistic           = "Sum"
      threshold           = var.alarm_5xx_threshold
      comparison_operator = "GreaterThanThreshold"
    }
    alb-unhealthy-targets = {
      description         = "At least one task is failing the load balancer health check."
      namespace           = "AWS/ApplicationELB"
      metric_name         = "UnHealthyHostCount"
      dimensions          = { LoadBalancer = module.alb.arn_suffix, TargetGroup = aws_lb_target_group.app.arn_suffix }
      statistic           = "Maximum"
      period              = 60
      evaluation_periods  = 5
      threshold           = 0
      comparison_operator = "GreaterThanThreshold"
    }
    db-cpu-high = {
      description         = "Database CPU above 80%."
      namespace           = "AWS/RDS"
      metric_name         = "CPUUtilization"
      dimensions          = { DBClusterIdentifier = module.database.cluster_identifier }
      threshold           = 80
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 3
    }
    db-capacity-high = {
      description         = "Database is using more than 90% of its maximum ACUs -- raise db_max_capacity."
      namespace           = "AWS/RDS"
      metric_name         = "ACUUtilization"
      dimensions          = { DBClusterIdentifier = module.database.cluster_identifier }
      threshold           = 90
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 3
    }
    cache-evictions = {
      description         = "The cache is evicting keys -- it is too small for the working set."
      namespace           = "AWS/ElastiCache"
      metric_name         = "Evictions"
      dimensions          = { CacheClusterId = "${module.cache.replication_group_id}-001" }
      statistic           = "Sum"
      threshold           = 0
      comparison_operator = "GreaterThanThreshold"
    }
  }
}

# --- Failed deployments --------------------------------------------------------
# The ECS circuit breaker rolls back a broken deploy on its own; this makes
# sure a human hears about it.

resource "aws_cloudwatch_event_rule" "deployment_failed" {
  name        = "${var.name}-deployment-failed"
  description = "ECS deployment of ${var.name} failed and was rolled back"

  event_pattern = jsonencode({
    source        = ["aws.ecs"]
    "detail-type" = ["ECS Deployment State Change"]
    resources     = [module.app.service_arn]
    detail        = { eventName = ["SERVICE_DEPLOYMENT_FAILED"] }
  })
}

resource "aws_cloudwatch_event_target" "deployment_failed" {
  rule = aws_cloudwatch_event_rule.deployment_failed.name
  arn  = aws_sns_topic.alerts.arn
}

# --- Chat notifier -------------------------------------------------------------

module "notifier_secret" {
  count  = var.alert_notifier_enabled ? 1 : 0
  source = "../../components/secretmanager"

  name_prefix = "${var.name}/alerting"
  secrets = {
    webhook-url = { description = "Incoming-webhook URL (Slack, Teams, ...) that receives ${var.name} alerts. Set the value by hand." }
  }
  recovery_window_in_days = 0
}

data "aws_iam_policy_document" "notifier" {
  count = var.alert_notifier_enabled ? 1 : 0

  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [module.notifier_secret[0].secret_arns["webhook-url"]]
  }
}

module "notifier" {
  count  = var.alert_notifier_enabled ? 1 : 0
  source = "../../components/lambda"

  function_name = "${var.name}-alert-notifier"
  description   = "Forwards ${var.name} alerts from SNS to a chat webhook"
  source_dir    = "${path.module}/notifier"
  handler       = "handler.lambda_handler"
  timeout       = 15
  policies      = { read-webhook-secret = data.aws_iam_policy_document.notifier[0].json }

  environment_variables = {
    WEBHOOK_SECRET_ARN = module.notifier_secret[0].secret_arns["webhook-url"]
  }
}

resource "aws_lambda_permission" "notifier_sns" {
  count = var.alert_notifier_enabled ? 1 : 0

  statement_id  = "AllowSnsInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.notifier[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}

resource "aws_sns_topic_subscription" "notifier" {
  count = var.alert_notifier_enabled ? 1 : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = module.notifier[0].function_arn
}
