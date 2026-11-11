# Environment-level settings for production. Read by live/aws/root.hcl and by
# the shared unit configs in live/aws/_common/.
locals {
  environment = "production"

  # ADOPT: replace with the real production AWS account ID. The provider
  # refuses to run against any other account (allowed_account_ids).
  account_id = "222222222222"

  # Public DNS. Hostnames are <service>.<domain>, e.g. api.example.com.
  domain = "example.com"

  # Route 53 hosted zone for `domain`. Leave null if DNS lives elsewhere: the
  # modules then output the records to create by hand instead of creating them.
  route53_zone_id = null

  vpc_cidr = "10.20.0.0/16"
  az_count = 2

  # Production optimises for availability and auditability.
  single_nat_gateway         = false
  enable_interface_endpoints = true
  enable_flow_logs           = true
  deletion_protection        = true
}
