# -----------------------------------------------------------------------------
# VPC network for one region
#
#   subnet          workloads: Cloud Run (Direct VPC egress), VMs
#   Cloud NAT       outbound internet for anything without a public IP
#   PSA range       Private Services Access: Cloud SQL / Memorystore get
#                   private IPs from this range, peered into the VPC
#
# Address plan inside the CIDR (shown for a /16):
#   subnet     10.x.0.0/20
#   PSA range  10.x.128.0/20
# -----------------------------------------------------------------------------

resource "google_compute_network" "this" {
  name                    = var.name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "this" {
  name          = "${var.name}-${var.region}"
  network       = google_compute_network.this.id
  region        = var.region
  ip_cidr_range = cidrsubnet(var.cidr, 4, 0)

  # Reach Google APIs (Storage, Secret Manager, ...) without public IPs.
  private_ip_google_access = true

  dynamic "log_config" {
    for_each = var.enable_flow_logs ? [1] : []
    content {
      aggregation_interval = "INTERVAL_5_MIN"
      flow_sampling        = 0.5
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }
}

resource "google_compute_router" "this" {
  name    = var.name
  network = google_compute_network.this.id
  region  = var.region
}

resource "google_compute_router_nat" "this" {
  name                               = var.name
  router                             = google_compute_router.this.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# --- Private Services Access (Cloud SQL private IP) -------------------------------

resource "google_compute_global_address" "private_services" {
  name          = "${var.name}-private-services"
  network       = google_compute_network.this.id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = cidrhost(cidrsubnet(var.cidr, 4, 8), 0)
  prefix_length = tonumber(split("/", cidrsubnet(var.cidr, 4, 8))[1])
}

resource "google_service_networking_connection" "private_services" {
  network                 = google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]
}
