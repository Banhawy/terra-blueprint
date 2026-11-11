# Shared configuration for queue-worker. Operational alarms go to web-api's
# alerts topic, so one webhook receives everything for the environment.
locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
  env    = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules//aws/services/queue-worker"
}

dependency "vpc" {
  config_path = "${get_terragrunt_dir()}/../../network/vpc"

  mock_outputs = {
    vpc_id             = "vpc-00000000000000000"
    private_subnet_ids = ["subnet-00000000000000003", "subnet-00000000000000004"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "web_api" {
  config_path = "${get_terragrunt_dir()}/../web-api"

  mock_outputs = {
    alerts_topic_arn = "arn:aws:sns:eu-central-1:000000000000:mock-alerts"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  name               = "${local.common.project}-${local.env.environment}-queue-worker"
  vpc_id             = dependency.vpc.outputs.vpc_id
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids
  alarm_topic_arn    = dependency.web_api.outputs.alerts_topic_arn
  force_destroy      = !local.env.deletion_protection
}
