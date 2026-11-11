locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
  env    = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  region = read_terragrunt_config(find_in_parent_folders("region.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules//gcp/services/web-api"
}

dependency "network" {
  config_path = "${get_terragrunt_dir()}/../../network/vpc"

  mock_outputs = {
    network_id = "projects/mock/global/networks/mock"
    subnet_id  = "projects/mock/regions/europe-west1/subnetworks/mock"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "registry" {
  config_path = "${get_terragrunt_dir()}/../../operations/artifact-registry"

  mock_outputs = {
    repository_url = "europe-west1-docker.pkg.dev/mock/mock"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  name       = "${local.common.project}-${local.env.environment}-web-api"
  region     = local.region.gcp_region
  network_id = dependency.network.outputs.network_id
  subnet_id  = dependency.network.outputs.subnet_id

  image_repository    = "${dependency.registry.outputs.repository_url}/web-api"
  deletion_protection = local.env.deletion_protection

  extra_environment = {
    APP_ENV = local.env.environment
  }
}
