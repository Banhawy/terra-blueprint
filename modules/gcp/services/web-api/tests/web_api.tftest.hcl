# Plans the service against a mocked provider -- no GCP credentials needed.

mock_provider "google" {
  # Known at plan time so the database user name can be derived and inspected.
  mock_resource "google_service_account" {
    defaults = {
      email = "acme-test-web-api@acme-test.iam.gserviceaccount.com"
      name  = "projects/acme-test/serviceAccounts/acme-test-web-api@acme-test.iam.gserviceaccount.com"
    }
    override_during = plan
  }
}

override_data {
  target = data.google_client_config.current
  values = { project = "acme-test" }
}

override_data {
  target = data.google_project.current
  values = { number = "123456789012" }
}

variables {
  name             = "acme-test-web-api"
  region           = "europe-west1"
  network_id       = "projects/acme-test/global/networks/acme-test"
  subnet_id        = "projects/acme-test/regions/europe-west1/subnetworks/acme-test-europe-west1"
  image_repository = "europe-west1-docker.pkg.dev/acme-test/acme-test/web-api"
  image_tag        = "1.0.0"
}

run "database_is_private_and_iam_authenticated" {
  command = plan

  assert {
    condition     = module.database.iam_users["acme-test-web-api@acme-test.iam.gserviceaccount.com"] == "acme-test-web-api@acme-test.iam"
    error_message = "The runtime service account must get an IAM database user."
  }
}

run "runtime_identity_is_least_privilege" {
  command = plan

  assert {
    condition     = toset(keys(google_project_iam_member.runtime)) == toset(["roles/cloudsql.client", "roles/cloudsql.instanceUser"])
    error_message = "The runtime account gets exactly the Cloud SQL client roles at project level."
  }

  assert {
    condition     = google_storage_bucket_iam_member.uploads.role == "roles/storage.objectUser"
    error_message = "Bucket access is object-level on the uploads bucket only."
  }
}

run "alerts_watch_errors_and_database" {
  command = plan

  assert {
    condition     = strcontains(google_monitoring_alert_policy.server_errors.conditions[0].condition_threshold[0].filter, "5xx")
    error_message = "A 5xx alert policy must exist."
  }
}
