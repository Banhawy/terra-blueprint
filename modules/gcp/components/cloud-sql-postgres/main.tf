# -----------------------------------------------------------------------------
# Cloud SQL for PostgreSQL, private IP only
#
# No public IP and TLS required. Applications log in with IAM database
# authentication as their own service account -- no passwords anywhere. The
# built-in `postgres` user is left without a password; reset one through the
# console only for break-glass access.
# -----------------------------------------------------------------------------

resource "google_sql_database_instance" "this" {
  name                = var.name
  region              = var.region
  database_version    = var.database_version
  deletion_protection = var.deletion_protection

  settings {
    edition           = "ENTERPRISE"
    tier              = var.tier
    availability_type = var.high_availability ? "REGIONAL" : "ZONAL"
    disk_type         = "PD_SSD"
    disk_size         = var.disk_size_gb
    disk_autoresize   = true

    deletion_protection_enabled = var.deletion_protection

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_id
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "02:00"
      transaction_log_retention_days = 7

      backup_retention_settings {
        retained_backups = var.backup_retention_count
      }
    }

    maintenance_window {
      day          = 7 # Sunday
      hour         = 3
      update_track = "stable"
    }

    insights_config {
      query_insights_enabled = true
    }

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }

    # Visibility into what the database is doing; cheap, and the first thing
    # you want during an incident.
    database_flags {
      name  = "log_min_duration_statement"
      value = "1000"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }
  }
}

resource "google_sql_database" "this" {
  name     = var.database_name
  instance = google_sql_database_instance.this.name
}

# One database user per application service account. Cloud SQL derives the
# username from the e-mail minus ".gserviceaccount.com".
resource "google_sql_user" "iam" {
  for_each = var.iam_service_account_emails

  name     = trimsuffix(each.value, ".gserviceaccount.com")
  instance = google_sql_database_instance.this.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}
