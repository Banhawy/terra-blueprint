output "url" {
  value       = module.service.uri
  description = "Service URL."
}

output "service_account_email" {
  value       = google_service_account.runtime.email
  description = "Runtime identity; grant it access to anything else the app needs."
}

output "database_connection_name" {
  value       = module.database.connection_name
  description = "Cloud SQL connection name (for the Cloud SQL Auth Proxy / connectors)."
}

output "database_private_ip" {
  value       = module.database.private_ip
  description = "Cloud SQL private IP."
}

output "uploads_bucket" {
  value       = module.uploads.name
  description = "Uploads bucket."
}

output "app_secret_ids" {
  value       = module.secrets.secret_ids
  description = "Secrets that need a value before the service can start (gcloud secrets versions add <id> --data-file=-)."
}
