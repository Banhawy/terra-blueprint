locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
  env    = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  region = read_terragrunt_config(find_in_parent_folders("region.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules//gcp/components/artifact-registry"
}

dependencies {
  paths = ["${get_terragrunt_dir()}/../project-services"]
}

inputs = {
  name   = "${local.common.project}-${local.env.environment}"
  region = local.region.gcp_region
}
