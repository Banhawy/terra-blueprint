output "uri" {
  value       = google_cloud_run_v2_service.this.uri
  description = "Service URL (https://<name>-<hash>.<region>.run.app)."
}

output "name" {
  value       = google_cloud_run_v2_service.this.name
  description = "Service name (service_name label on Cloud Run metrics)."
}
