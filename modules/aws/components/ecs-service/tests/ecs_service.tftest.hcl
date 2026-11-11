mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "eu-central-1" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}

variables {
  name           = "acme-test-api"
  vpc_id         = "vpc-0123456789abcdef0"
  subnet_ids     = ["subnet-a", "subnet-b"]
  image          = "public.ecr.aws/nginx/nginx:stable"
  container_port = 8080
  environment    = { FOO = "bar" }
  secrets        = { API_KEY = "arn:aws:secretsmanager:eu-central-1:111111111111:secret:key" }
  secret_arns    = ["arn:aws:secretsmanager:eu-central-1:111111111111:secret:key"]
}

run "failed_deploys_roll_back" {
  command = plan

  assert {
    condition     = one(aws_ecs_service.this.deployment_circuit_breaker).enable && one(aws_ecs_service.this.deployment_circuit_breaker).rollback
    error_message = "The deployment circuit breaker must be on with rollback."
  }

  assert {
    condition     = one(aws_ecs_service.this.network_configuration).assign_public_ip == false
    error_message = "Tasks must not get public IPs."
  }
}

run "secrets_are_not_plain_environment" {
  command = plan

  assert {
    condition     = jsondecode(aws_ecs_task_definition.this.container_definitions)[0].secrets[0].name == "API_KEY"
    error_message = "Secrets must be passed as ECS secrets (resolved at start), not environment values."
  }

  assert {
    condition     = !strcontains(jsonencode(jsondecode(aws_ecs_task_definition.this.container_definitions)[0].environment), "secretsmanager")
    error_message = "No secret reference may leak into the plain environment."
  }
}

run "autoscaling_only_when_range_given" {
  command = plan

  assert {
    condition     = length(aws_appautoscaling_target.this) == 0
    error_message = "min == max must not create autoscaling."
  }
}
