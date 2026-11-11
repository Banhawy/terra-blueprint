# -----------------------------------------------------------------------------
# Organisation-wide settings, read by every cloud's root.hcl.
#
# ADOPTING THIS BLUEPRINT: this file is the first thing to change. `project`
# becomes the prefix of every resource name and state bucket, so pick it once.
# -----------------------------------------------------------------------------
locals {
  # Short, lowercase, DNS-safe. Prefixes resource names: <project>-<env>-<thing>.
  project = "acme"

  # Team that owns the infrastructure. Lands in tags (AWS) and labels (GCP).
  owner = "platform"

  # Where this repository lives. Used to scope the CI trust policies (GitHub
  # OIDC on AWS, Workload Identity Federation on GCP) to this repo only.
  github_org  = "acme"
  github_repo = "infrastructure"

  # Tags applied to every AWS resource via provider default_tags. GCP gets the
  # same values as labels (lower-cased, see live/gcp/root.hcl).
  tags = {
    Project   = local.project
    Owner     = local.owner
    ManagedBy = "terraform"
  }
}
