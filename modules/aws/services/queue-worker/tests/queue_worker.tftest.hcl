mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }
  mock_data "aws_region" {
    defaults = { region = "eu-central-1" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_data "aws_ssm_parameter" {
    defaults = { value = "ami-0123456789abcdef0" }
  }
  mock_data "aws_default_tags" {
    defaults = { tags = { Project = "acme" } }
  }
  # Known at plan time so the redrive policy can be inspected.
  mock_resource "aws_sqs_queue" {
    defaults = {
      arn = "arn:aws:sqs:eu-central-1:111111111111:mock-queue"
      url = "https://sqs.eu-central-1.amazonaws.com/111111111111/mock-queue"
    }
    override_during = plan
  }
}

variables {
  name               = "acme-test-queue-worker"
  vpc_id             = "vpc-0123456789abcdef0"
  private_subnet_ids = ["subnet-prv-a", "subnet-prv-b"]
}

run "failed_jobs_are_dead_lettered" {
  command = plan

  assert {
    condition     = jsondecode(aws_sqs_queue.jobs.redrive_policy).maxReceiveCount == 3
    error_message = "Messages must move to the DLQ after 3 failed receives."
  }

  assert {
    condition     = aws_sqs_queue.jobs.visibility_timeout_seconds == var.job_timeout_seconds
    error_message = "The visibility timeout must cover the longest job, or jobs run twice."
  }

  assert {
    condition     = aws_sqs_queue.jobs.sqs_managed_sse_enabled && aws_sqs_queue.dlq.sqs_managed_sse_enabled
    error_message = "Both queues must be encrypted at rest."
  }
}

run "ships_only_source_files" {
  command = plan

  assert {
    condition     = toset(keys(aws_s3_object.code)) == toset(["requirements.txt", "worker.py"])
    error_message = "Only worker source files are uploaded (no caches)."
  }

  assert {
    condition     = alltrue([for k, o in aws_s3_object.code : startswith(o.key, "${local.code_hash}/")])
    error_message = "Code keys must embed the code hash so a change rolls the instances."
  }
}
