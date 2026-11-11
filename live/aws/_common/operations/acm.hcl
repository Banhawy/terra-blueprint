# Regional wildcard certificate for load balancers (*.staging.example.com).
# CloudFront certificates live in us-east-1 and are created by static-site.
locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules//aws/components/acm"
}

inputs = {
  domain_name               = local.env.domain
  subject_alternative_names = ["*.${local.env.domain}"]
  route53_zone_id           = local.env.route53_zone_id
}
