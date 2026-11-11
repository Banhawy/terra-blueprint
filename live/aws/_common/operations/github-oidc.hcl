# Keyless CI for this repository: GitHub Actions assumes these roles via OIDC.
#
#   terraform-plan   pull requests -- read-only plus state access
#   terraform-apply  the GitHub Environment named after this environment
#                    (staging auto-applies from main; production needs approval)
#
# This unit is applied once by an administrator from a workstation (CI cannot
# assume roles that do not exist yet). See README "First apply".
locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
  env    = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  region = read_terragrunt_config(find_in_parent_folders("region.hcl")).locals

  repo         = "repo:${local.common.github_org}/${local.common.github_repo}"
  state_bucket = "${local.common.project}-tfstate-${local.env.account_id}-${local.region.aws_region}"
}

terraform {
  source = "${get_repo_root()}/modules//aws/components/github-oidc"
}

inputs = {
  name_prefix = "${local.common.project}-${local.env.environment}-github"

  roles = {
    terraform-plan = {
      description         = "Plans from pull requests: read-only, plus the state lock file."
      subjects            = ["${local.repo}:pull_request"]
      managed_policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
      inline_policies = {
        state = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect   = "Allow"
              Action   = ["s3:ListBucket"]
              Resource = "arn:aws:s3:::${local.state_bucket}"
            },
            {
              Effect   = "Allow"
              Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
              Resource = "arn:aws:s3:::${local.state_bucket}/*"
            },
          ]
        })
      }
    }

    # ADOPT: AdministratorAccess keeps the blueprint working out of the box.
    # Narrow it (or add a permissions boundary) once you know what you manage.
    terraform-apply = {
      description          = "Applies from the ${local.env.environment} GitHub Environment."
      subjects             = ["${local.repo}:environment:${local.env.environment}"]
      managed_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
      max_session_duration = 7200
    }
  }
}
