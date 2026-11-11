# Plans the service against mocked providers -- no AWS credentials needed.
#   terraform init -backend=false && terraform test

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }
  mock_data "aws_region" {
    defaults = { region = "eu-central-1" }
  }
  mock_data "aws_rds_engine_version" {
    defaults = { version = "17.5" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  # Known at plan time so assertions can inspect values derived from it.
  mock_resource "aws_ecs_service" {
    defaults        = { id = "arn:aws:ecs:eu-central-1:111111111111:service/acme-test-web-api/acme-test-web-api" }
    override_during = plan
  }
}

mock_provider "archive" {}

variables {
  name                = "acme-test-web-api"
  vpc_id              = "vpc-0123456789abcdef0"
  vpc_cidr            = "10.10.0.0/16"
  public_subnet_ids   = ["subnet-pub-a", "subnet-pub-b"]
  private_subnet_ids  = ["subnet-prv-a", "subnet-prv-b"]
  database_subnet_ids = ["subnet-db-a", "subnet-db-b"]
  hostname            = "api.test.example.com"
  certificate_arn     = "arn:aws:acm:eu-central-1:111111111111:certificate/test"
  image_repository    = "111111111111.dkr.ecr.eu-central-1.amazonaws.com/acme/web-api"
  image_tag           = "1.0.0"
}

run "routes_only_its_hostname_to_the_app" {
  command = plan

  assert {
    condition     = one(one(aws_lb_listener_rule.app.condition).host_header).values == toset(["api.test.example.com"])
    error_message = "The listener rule must match exactly the service hostname."
  }

  assert {
    condition     = one(aws_lb_target_group.app.health_check).path == "/healthz"
    error_message = "Health check should poll /healthz by default."
  }
}

run "dns_records_output_without_route53" {
  command = plan

  assert {
    condition     = length(output.dns_records) == 1 && output.dns_records[0].name == "api.test.example.com"
    error_message = "Without a hosted zone the module must output the record to create."
  }

  assert {
    condition     = length(aws_route53_record.api) == 0
    error_message = "No Route 53 record may be created without a zone."
  }
}

run "route53_record_with_zone" {
  command = plan

  variables {
    route53_zone_id = "Z0123456789"
  }

  assert {
    condition     = length(aws_route53_record.api) == 1 && length(output.dns_records) == 0
    error_message = "With a hosted zone the record is managed and nothing is left to do by hand."
  }
}

run "alerts_reach_the_notifier" {
  command = plan

  assert {
    condition     = length(aws_sns_topic_subscription.notifier) == 1 && aws_sns_topic_subscription.notifier[0].protocol == "lambda"
    error_message = "The alerts topic must be subscribed by the notifier Lambda."
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_event_rule.deployment_failed.event_pattern).detail.eventName == ["SERVICE_DEPLOYMENT_FAILED"]
    error_message = "Failed deployments must be routed to the alerts topic."
  }
}

run "scheduled_tasks_become_schedules" {
  command = plan

  variables {
    scheduled_tasks = {
      nightly = {
        description         = "Nightly cleanup"
        schedule_expression = "cron(0 3 * * ? *)"
        command             = ["echo", "hello"]
      }
      paused = {
        description         = "Disabled job"
        schedule_expression = "rate(1 hour)"
        command             = ["true"]
        enabled             = false
      }
    }
  }

  assert {
    condition     = keys(aws_scheduler_schedule.task) == ["nightly"]
    error_message = "Only enabled scheduled tasks get a schedule."
  }

  assert {
    condition     = jsondecode(aws_scheduler_schedule.task["nightly"].target[0].input).containerOverrides[0].command == ["echo", "hello"]
    error_message = "The schedule must override the container command."
  }
}
