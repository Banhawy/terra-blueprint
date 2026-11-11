output "provider_name" {
  value       = google_iam_workload_identity_pool_provider.github.name
  description = "Full provider name -- the `workload_identity_provider` input of google-github-actions/auth."
}

output "service_account_emails" {
  value       = { for k, sa in google_service_account.this : k => sa.email }
  description = "Map of key to service account e-mail -- the `service_account` input of google-github-actions/auth."
}
