# Container image repositories. Each account has its own; CI pushes the image
# that a given environment deploys.
locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules//aws/components/ecr"
}

inputs = {
  repositories = ["${local.common.project}/web-api"]
}
