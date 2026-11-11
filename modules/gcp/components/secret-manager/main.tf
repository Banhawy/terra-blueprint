# Creates secret containers only; values (versions) are added out of band
# (`gcloud secrets versions add`), so they never pass through Terraform state.
resource "google_secret_manager_secret" "this" {
  for_each = var.secrets

  secret_id = "${var.name_prefix}-${each.key}"
  labels    = { purpose = "app" }
  annotations = {
    description = each.value.description
  }

  replication {
    auto {}
  }
}
