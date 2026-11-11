output "network_id" {
  value       = google_compute_network.this.id
  description = "Network ID (projects/<p>/global/networks/<name>)."
}

output "network_name" {
  value       = google_compute_network.this.name
  description = "Network name."
}

output "subnet_id" {
  value       = google_compute_subnetwork.this.id
  description = "Subnet ID, for Cloud Run Direct VPC egress and VMs."
}

output "subnet_cidr" {
  value       = google_compute_subnetwork.this.ip_cidr_range
  description = "Subnet range."
}

output "private_services_connection" {
  value       = google_service_networking_connection.private_services.id
  description = "Private Services Access peering; Cloud SQL private IP depends on it."
}
