# Keyless CI for this repository on GCP -- the counterpart of the AWS
# github-oidc unit. Applied once by an administrator; see README "First apply".
locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
  env    = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals

  repo         = "repo:${local.common.github_org}/${local.common.github_repo}"
  state_bucket = "${local.env.project_id}-tfstate"
}

terraform {
  source = "${get_repo_root()}/modules//gcp/components/workload-identity-federation"
}

dependencies {
  paths = ["${get_terragrunt_dir()}/../project-services"]
}

inputs = {
  github_org  = local.common.github_org
  name_prefix = "github"

  service_accounts = {
    tf-plan = {
      description   = "Plans from pull requests: read-only, plus the state bucket."
      subjects      = ["${local.repo}:pull_request"]
      project_roles = ["roles/viewer", "roles/iam.securityReviewer"]
      bucket_roles  = [{ bucket = local.state_bucket, role = "roles/storage.objectUser" }]
    }

    # ADOPT: roles/owner keeps the blueprint working out of the box. Narrow it
    # to the roles your stack actually needs.
    tf-apply = {
      description   = "Applies from the ${local.env.environment} GitHub Environment."
      subjects      = ["${local.repo}:environment:${local.env.environment}"]
      project_roles = ["roles/owner"]
    }
  }
}
