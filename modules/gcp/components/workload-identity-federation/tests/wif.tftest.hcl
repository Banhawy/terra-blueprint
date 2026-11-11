mock_provider "google" {}

override_data {
  target = data.google_client_config.current
  values = { project = "acme-test" }
}

variables {
  github_org  = "acme"
  name_prefix = "gh"
}

run "only_the_org_is_trusted" {
  command = plan

  variables {
    service_accounts = {
      plan = {
        description = "Plans"
        subjects    = ["repo:acme/infrastructure:pull_request"]
      }
    }
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.github.attribute_condition == "assertion.repository_owner == 'acme'"
    error_message = "The provider must only accept tokens from the configured organisation."
  }
}

run "rejects_unscoped_subjects" {
  command = plan

  variables {
    service_accounts = {
      bad = {
        description = "Trusts anything"
        subjects    = ["*"]
      }
    }
  }

  expect_failures = [var.service_accounts]
}
