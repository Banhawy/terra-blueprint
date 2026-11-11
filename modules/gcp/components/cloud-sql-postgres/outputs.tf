output "instance_name" {
  value       = google_sql_database_instance.this.name
  description = "Instance name."
}

output "connection_name" {
  value       = google_sql_database_instance.this.connection_name
  description = "<project>:<region>:<instance>, for the Cloud SQL connectors."
}

output "private_ip" {
  value       = google_sql_database_instance.this.private_ip_address
  description = "Private IP address inside the VPC."
}

output "database_name" {
  value       = google_sql_database.this.name
  description = "Application database."
}

output "iam_users" {
  value       = { for k, u in google_sql_user.iam : k => u.name }
  description = "Service account e-mail -> database username."
}
