# Environment-level settings for GCP staging. Read by live/gcp/root.hcl and by
# the shared unit configs in live/gcp/_common/.
locals {
  environment = "staging"

  # ADOPT: replace with the real GCP project ID. The project must already exist
  # with billing enabled -- this repo does not create projects.
  project_id = "acme-staging"

  # Network. Does not overlap the AWS environments (10.10/16, 10.20/16).
  vpc_cidr = "10.30.0.0/16"

  deletion_protection = false
}
