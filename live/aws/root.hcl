# -----------------------------------------------------------------------------
# Root configuration for every AWS unit under live/aws/.
#
# Every unit includes this file with:
#
#   include "root" {
#     path   = find_in_parent_folders("root.hcl")
#     expose = true
#   }
#
# It generates provider.tf and backend.tf for the unit. Never write those files
# by hand: they are overwritten on every run.
#
# Values cascade down the directory tree:
#   common.hcl   (repo root)        project, owner, tags
#   env.hcl      (live/aws/<env>)   environment, account_id, domain, sizing knobs
#   region.hcl   (.../<region>)     aws_region
# -----------------------------------------------------------------------------
locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl"))
  env    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  project     = local.common.locals.project
  github_org  = local.common.locals.github_org
  github_repo = local.common.locals.github_repo
  environment = local.env.locals.environment
  account_id  = local.env.locals.account_id
  aws_region  = local.region.locals.aws_region

  # <project>-<environment>, e.g. "acme-staging". Units prefix every name with it.
  name_prefix = "${local.project}-${local.environment}"

  # Applied to every taggable resource through the provider, so no module needs a
  # tags variable and no resource can forget one. `Unit` records which directory
  # under live/aws/ owns a resource -- the fastest way back from the console to code.
  default_tags = merge(local.common.locals.tags, {
    Environment = local.environment
    Unit        = path_relative_to_include()
  })
}

terragrunt_version_constraint = ">= 1.2.0"

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region              = "${local.aws_region}"
      allowed_account_ids = ["${local.account_id}"]

      default_tags {
        tags = ${jsonencode(local.default_tags)}
      }
    }

    # CloudFront only accepts ACM certificates (and WAF web ACLs) from us-east-1.
    # Modules that need it reference `provider = aws.us_east_1`; units that do not
    # simply leave it unused.
    provider "aws" {
      alias               = "us_east_1"
      region              = "us-east-1"
      allowed_account_ids = ["${local.account_id}"]

      default_tags {
        tags = ${jsonencode(local.default_tags)}
      }
    }
  EOF
}

# One state bucket per account and region. Create it once with
#   terragrunt backend bootstrap --all
# (see README "First apply"). Terragrunt creates it versioned, encrypted, with
# public access blocked and TLS enforced. Locking uses S3's native lock file,
# so there is no DynamoDB lock table.
remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket       = "${local.project}-tfstate-${local.account_id}-${local.aws_region}"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.aws_region
    encrypt      = true
    use_lockfile = true
  }
}
