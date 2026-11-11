# Shared configuration for the VPC unit in every AWS environment. Environment
# differences come from env.hcl; a unit can still override any input locally.
locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
  env    = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules//aws/components/vpc"
}

inputs = {
  name                       = "${local.common.project}-${local.env.environment}"
  cidr                       = local.env.vpc_cidr
  az_count                   = local.env.az_count
  single_nat_gateway         = local.env.single_nat_gateway
  enable_interface_endpoints = local.env.enable_interface_endpoints
  enable_flow_logs           = local.env.enable_flow_logs
}
