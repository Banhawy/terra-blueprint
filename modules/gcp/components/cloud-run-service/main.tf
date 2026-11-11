# -----------------------------------------------------------------------------
# Cloud Run (v2) service
#
# Runs as a dedicated, caller-provided service account; reaches private
# resources (Cloud SQL private IP) through Direct VPC egress -- no Serverless
# VPC Access connector to run or pay for. Secrets are injected from Secret
# Manager at start; the service account gets accessor on exactly those secrets.
# -----------------------------------------------------------------------------

resource "google_cloud_run_v2_service" "this" {
  name                = var.name
  location            = var.region
  ingress             = var.ingress
  deletion_protection = var.deletion_protection

  template {
    service_account                  = var.service_account_email
    max_instance_request_concurrency = var.concurrency
    timeout                          = "${var.request_timeout_seconds}s"

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    dynamic "vpc_access" {
      for_each = var.subnet_id == null ? [] : [1]
      content {
        # Only private ranges go through the VPC; public traffic goes out
        # directly, so Cloud NAT is not on the hot path for API calls.
        egress = "PRIVATE_RANGES_ONLY"
        network_interfaces {
          subnetwork = var.subnet_id
        }
      }
    }

    containers {
      image = var.image

      ports {
        container_port = var.container_port
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
        cpu_idle          = true # CPU only while handling requests (cheaper)
        startup_cpu_boost = true
      }

      dynamic "env" {
        for_each = var.environment
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.secrets
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value
              version = "latest"
            }
          }
        }
      }

      startup_probe {
        http_get {
          path = var.health_check_path
        }
        initial_delay_seconds = 0
        period_seconds        = 5
        failure_threshold     = 24 # up to 2 minutes to start
      }

      liveness_probe {
        http_get {
          path = var.health_check_path
        }
        period_seconds    = 30
        failure_threshold = 3
      }
    }
  }

  depends_on = [google_secret_manager_secret_iam_member.accessor]
}

# Read access to exactly the secrets this service uses.
resource "google_secret_manager_secret_iam_member" "accessor" {
  for_each = var.secrets

  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.service_account_email}"
}

# A public API must be invokable without Google credentials; the app authenticates users.
resource "google_cloud_run_v2_service_iam_member" "public" {
  count = var.allow_unauthenticated ? 1 : 0

  name     = google_cloud_run_v2_service.this.name
  location = google_cloud_run_v2_service.this.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}
