# Environment-level settings for staging. Read by live/aws/root.hcl and by the
# shared unit configs in live/aws/_common/.
locals {
  environment = "staging"

  # ADOPT: replace with the real staging AWS account ID. The provider refuses
  # to run against any other account (allowed_account_ids).
  account_id = "111111111111"

  # Public DNS. Hostnames are <service>.<domain>, e.g. api.staging.example.com.
  domain = "staging.example.com"

  # Route 53 hosted zone for `domain`. Leave null if DNS lives elsewhere: the
  # modules then output the records to create by hand instead of creating them.
  route53_zone_id = null

  # Network. Each environment gets a non-overlapping /16 so peering or a transit
  # gateway stays possible later.
  vpc_cidr = "10.10.0.0/16"
  az_count = 2

  # Cost / availability trade-offs. Staging optimises for cost.
  single_nat_gateway         = true
  enable_interface_endpoints = false
  enable_flow_logs           = false
  deletion_protection        = false
}
