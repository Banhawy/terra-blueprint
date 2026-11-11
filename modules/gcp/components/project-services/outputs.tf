output "enabled_services" {
  value       = sort([for s in google_project_service.this : s.service])
  description = "APIs enabled by this module."
}
