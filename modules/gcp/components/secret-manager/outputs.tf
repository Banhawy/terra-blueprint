output "secret_ids" {
  value       = { for k, s in google_secret_manager_secret.this : k => s.secret_id }
  description = "Map of key to secret ID (what Cloud Run's secret_key_ref expects)."
}

output "secret_names" {
  value       = { for k, s in google_secret_manager_secret.this : k => s.name }
  description = "Map of key to full resource name (projects/<n>/secrets/<id>)."
}
