resource "google_artifact_registry_repository" "this" {
  repository_id = var.name
  location      = var.region
  format        = "DOCKER"
  description   = var.description

  docker_config {
    # A tag always means the same image: deploys are reproducible.
    immutable_tags = true
  }

  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = var.keep_recent_versions
    }
  }

  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "${var.untagged_expiry_days * 86400}s"
    }
  }
}
