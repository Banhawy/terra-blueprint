# Shared configuration for static-site: app.<domain>, proxying /api/* to
# web-api on the same origin, with a deploy role for the frontend repository.
locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
  env    = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals

  # ADOPT: the repository whose CI builds and uploads the frontend.
  frontend_repo = "web-frontend"
}

terraform {
  source = "${get_repo_root()}/modules//aws/services/static-site"
}

dependency "web_api" {
  config_path = "${get_terragrunt_dir()}/../web-api"

  mock_outputs = {
    hostname = "api.${local.env.domain}"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "github_oidc" {
  config_path = "${get_terragrunt_dir()}/../../operations/github-oidc"

  mock_outputs = {
    oidc_provider_arn = "arn:aws:iam::000000000000:oidc-provider/token.actions.githubusercontent.com"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  name              = "${local.common.project}-${local.env.environment}-static-site"
  domain_name       = "app.${local.env.domain}"
  route53_zone_id   = local.env.route53_zone_id
  api_origin_domain = dependency.web_api.outputs.hostname

  deploy_role = {
    oidc_provider_arn = dependency.github_oidc.outputs.oidc_provider_arn
    subjects          = ["repo:${local.common.github_org}/${local.frontend_repo}:environment:${local.env.environment}"]
  }
}
