mock_provider "google" {}

variables {
  name     = "acme-test-bucket"
  location = "europe-west1"
}

run "bucket_cannot_be_made_public" {
  command = plan

  assert {
    condition     = google_storage_bucket.this.public_access_prevention == "enforced"
    error_message = "Public access prevention must be enforced."
  }

  assert {
    condition     = google_storage_bucket.this.uniform_bucket_level_access
    error_message = "Uniform bucket-level access must be on (no object ACLs)."
  }
}
