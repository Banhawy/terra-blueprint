# A private bucket: uniform bucket-level access (no per-object ACLs) and
# public access prevention enforced, so no IAM binding can make it public.
resource "google_storage_bucket" "this" {
  name          = var.name
  location      = var.location
  storage_class = "STANDARD"
  force_destroy = var.force_destroy

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = var.versioning_enabled
  }

  dynamic "lifecycle_rule" {
    for_each = var.versioning_enabled && var.noncurrent_version_expiration_days != null ? [1] : []
    content {
      action {
        type = "Delete"
      }
      condition {
        days_since_noncurrent_time = var.noncurrent_version_expiration_days
        with_state                 = "ARCHIVED"
      }
    }
  }

  dynamic "lifecycle_rule" {
    for_each = var.expiration_days == null ? [] : [1]
    content {
      action {
        type = "Delete"
      }
      condition {
        age = var.expiration_days
      }
    }
  }

  dynamic "cors" {
    for_each = length(var.cors_origins) == 0 ? [] : [1]
    content {
      origin          = var.cors_origins
      method          = ["GET", "PUT", "POST"]
      response_header = ["Content-Type", "ETag"]
      max_age_seconds = 3000
    }
  }

  dynamic "encryption" {
    for_each = var.kms_key_name == null ? [] : [1]
    content {
      default_kms_key_name = var.kms_key_name
    }
  }
}
