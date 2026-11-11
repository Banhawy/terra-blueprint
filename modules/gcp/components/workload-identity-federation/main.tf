# -----------------------------------------------------------------------------
# Keyless CI on GCP: GitHub Actions exchanges its OIDC token for short-lived
# credentials of a service account. No service-account keys exist.
#
# Same model as the AWS github-oidc component: each service account trusts an
# explicit list of token subjects ("repo:<org>/<repo>:environment:<env>").
# -----------------------------------------------------------------------------

# The provider's default project.
data "google_client_config" "current" {}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = var.pool_id
  display_name              = "GitHub Actions"
  description               = "Identities issued by GitHub Actions for ${var.github_org}"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  # Only tokens from this GitHub organisation are accepted at all.
  attribute_condition = "assertion.repository_owner == '${var.github_org}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "this" {
  for_each = var.service_accounts

  account_id   = "${var.name_prefix}-${each.key}"
  display_name = each.value.description
}

resource "google_project_iam_member" "this" {
  for_each = merge([
    for sa, cfg in var.service_accounts : {
      for role in cfg.project_roles : "${sa}|${role}" => { sa = sa, role = role }
    }
  ]...)

  project = data.google_client_config.current.project
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.this[each.value.sa].email}"
}

resource "google_storage_bucket_iam_member" "this" {
  for_each = merge([
    for sa, cfg in var.service_accounts : {
      for b in cfg.bucket_roles : "${sa}|${b.bucket}|${b.role}" => { sa = sa, bucket = b.bucket, role = b.role }
    }
  ]...)

  bucket = each.value.bucket
  role   = each.value.role
  member = "serviceAccount:${google_service_account.this[each.value.sa].email}"
}

# Let tokens with the listed subjects impersonate the service account.
resource "google_service_account_iam_member" "workload_identity_user" {
  for_each = merge([
    for sa, cfg in var.service_accounts : {
      for subject in cfg.subjects : "${sa}|${subject}" => { sa = sa, subject = subject }
    }
  ]...)

  service_account_id = google_service_account.this[each.value.sa].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/subject/${each.value.subject}"
}
