output "name" {
  value       = google_storage_bucket.this.name
  description = "Bucket name."
}

output "url" {
  value       = google_storage_bucket.this.url
  description = "gs:// URL."
}
