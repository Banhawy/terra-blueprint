# Shared configuration for web-api. Per-environment units set image_tag and
# sizing; everything else is derived from env.hcl and dependency outputs.
locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
  env    = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules//aws/services/web-api"
}

# Mock outputs let `validate` and the first `plan` run before the dependency
# has been applied. They are never used by `apply`.
dependency "vpc" {
  config_path = "${get_terragrunt_dir()}/../../network/vpc"

  mock_outputs = {
    vpc_id              = "vpc-00000000000000000"
    vpc_cidr            = "10.0.0.0/16"
    public_subnet_ids   = ["subnet-00000000000000001", "subnet-00000000000000002"]
    private_subnet_ids  = ["subnet-00000000000000003", "subnet-00000000000000004"]
    database_subnet_ids = ["subnet-00000000000000005", "subnet-00000000000000006"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "acm" {
  config_path = "${get_terragrunt_dir()}/../../operations/acm"

  mock_outputs = {
    certificate_arn = "arn:aws:acm:eu-central-1:000000000000:certificate/00000000-0000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "ecr" {
  config_path = "${get_terragrunt_dir()}/../../operations/ecr"

  mock_outputs = {
    repository_urls = { "${local.common.project}/web-api" = "000000000000.dkr.ecr.eu-central-1.amazonaws.com/${local.common.project}/web-api" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  name = "${local.common.project}-${local.env.environment}-web-api"

  vpc_id              = dependency.vpc.outputs.vpc_id
  vpc_cidr            = dependency.vpc.outputs.vpc_cidr
  public_subnet_ids   = dependency.vpc.outputs.public_subnet_ids
  private_subnet_ids  = dependency.vpc.outputs.private_subnet_ids
  database_subnet_ids = dependency.vpc.outputs.database_subnet_ids

  hostname        = "api.${local.env.domain}"
  certificate_arn = dependency.acm.outputs.certificate_arn
  route53_zone_id = local.env.route53_zone_id

  image_repository     = dependency.ecr.outputs.repository_urls["${local.common.project}/web-api"]
  uploads_cors_origins = ["https://app.${local.env.domain}"]
  deletion_protection  = local.env.deletion_protection

  extra_environment = {
    APP_ENV = local.env.environment
  }
}
