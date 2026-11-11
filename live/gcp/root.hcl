# -----------------------------------------------------------------------------
# Root configuration for every GCP unit under live/gcp/.
#
# Same shape as live/aws/root.hcl: every unit includes this file, which
# generates provider.tf and backend.tf. Never write those files by hand.
#
# Values cascade down the directory tree:
#   common.hcl   (repo root)        project, owner, tags
#   env.hcl      (live/gcp/<env>)   environment, project_id, sizing knobs
#   region.hcl   (.../<region>)     gcp_region
# -----------------------------------------------------------------------------
locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl"))
  env    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  project     = local.common.locals.project
  github_org  = local.common.locals.github_org
  github_repo = local.common.locals.github_repo
  environment = local.env.locals.environment
  project_id  = local.env.locals.project_id
  gcp_region  = local.region.locals.gcp_region

  name_prefix = "${local.project}-${local.environment}"

  # GCP labels must be lowercase (keys and values), so the shared tags are
  # normalised here rather than in every module.
  default_labels = {
    for k, v in merge(local.common.locals.tags, { Environment = local.environment }) :
    lower(k) => lower(replace(v, "/[^a-zA-Z0-9_-]/", "-"))
  }
}

terragrunt_version_constraint = ">= 1.2.0"

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "google" {
      project        = "${local.project_id}"
      region         = "${local.gcp_region}"
      default_labels = ${jsonencode(local.default_labels)}
    }
  EOF
}

# One state bucket per GCP project. Create it once with
#   terragrunt backend bootstrap --all
# GCS provides state locking natively.
remote_state {
  backend = "gcs"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket   = "${local.project_id}-tfstate"
    prefix   = path_relative_to_include()
    project  = local.project_id
    location = local.gcp_region
  }
}
