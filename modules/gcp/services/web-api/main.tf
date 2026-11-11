# -----------------------------------------------------------------------------
# web-api on GCP: the same shape as the AWS service, on managed equivalents
#
#   internet -> Cloud Run (*.run.app) ──Direct VPC egress──> Cloud SQL (private IP)
#                   │                                         (IAM database auth)
#                   ├─> Secret Manager (app secrets)
#                   └─> GCS uploads bucket
#
# AWS -> GCP: ECS Fargate -> Cloud Run, Aurora -> Cloud SQL, S3 -> GCS,
# Secrets Manager -> Secret Manager, CloudWatch alarms -> Cloud Monitoring.
#
# Next step for production: a global external HTTPS load balancer with a
# serverless NEG in front (custom domain, Cloud Armor = the ALB + WAF of the
# AWS version), then set ingress to INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER.
# -----------------------------------------------------------------------------

# The provider's default project. (google_project.project_id is input-only,
# so read the ID here and look the project up by it for its number.)
data "google_client_config" "current" {}

data "google_project" "current" {
  project_id = data.google_client_config.current.project
}

locals {
  app_secrets = {
    for k, id in module.secrets.secret_ids : upper(replace(k, "-", "_")) => id
  }
}

# Dedicated runtime identity: never run workloads as the default compute SA.
resource "google_service_account" "runtime" {
  account_id   = substr(var.name, 0, 30)
  display_name = "Runtime identity of ${var.name}"
}

module "secrets" {
  source = "../../components/secret-manager"

  name_prefix = var.name
  secrets     = var.app_secrets
}

module "uploads" {
  source = "../../components/gcs-bucket"

  name          = "${var.name}-uploads-${data.google_project.current.number}"
  location      = var.region
  force_destroy = !var.deletion_protection
  cors_origins  = var.uploads_cors_origins
}

module "database" {
  source = "../../components/cloud-sql-postgres"

  name                       = var.name
  region                     = var.region
  network_id                 = var.network_id
  tier                       = var.db_tier
  high_availability          = var.db_high_availability
  database_name              = var.db_name
  iam_service_account_emails = [google_service_account.runtime.email]
  deletion_protection        = var.deletion_protection
}

module "service" {
  source = "../../components/cloud-run-service"

  name                  = var.name
  region                = var.region
  image                 = "${var.image_repository}:${var.image_tag}"
  service_account_email = google_service_account.runtime.email
  subnet_id             = var.subnet_id
  container_port        = var.container_port
  health_check_path     = var.health_check_path
  min_instances         = var.min_instances
  max_instances         = var.max_instances
  allow_unauthenticated = var.allow_unauthenticated
  deletion_protection   = var.deletion_protection

  environment = merge(
    {
      DATABASE_HOST     = module.database.private_ip
      DATABASE_NAME     = module.database.database_name
      DATABASE_USER     = module.database.iam_users[google_service_account.runtime.email]
      DATABASE_IAM_AUTH = "true"
      UPLOADS_BUCKET    = module.uploads.name
    },
    var.extra_environment,
  )
  secrets = local.app_secrets
}

# --- Runtime permissions -----------------------------------------------------------

resource "google_project_iam_member" "runtime" {
  for_each = toset([
    "roles/cloudsql.client",       # connect through the Cloud SQL connectors
    "roles/cloudsql.instanceUser", # log in with IAM database authentication
  ])

  project = data.google_client_config.current.project
  role    = each.value
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_storage_bucket_iam_member" "uploads" {
  bucket = module.uploads.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.runtime.email}"
}

# --- Alerting ------------------------------------------------------------------------

resource "google_monitoring_alert_policy" "server_errors" {
  display_name = "${var.name}: 5xx responses"
  combiner     = "OR"

  conditions {
    display_name = "5xx rate above ${var.alarm_5xx_per_minute}/min"
    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${module.service.name}\" AND metric.type = \"run.googleapis.com/request_count\" AND metric.labels.response_code_class = \"5xx\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.alarm_5xx_per_minute
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = var.notification_channels
}

resource "google_monitoring_alert_policy" "database_cpu" {
  display_name = "${var.name}: database CPU"
  combiner     = "OR"

  conditions {
    display_name = "Cloud SQL CPU above 80%"
    condition_threshold {
      filter          = "resource.type = \"cloudsql_database\" AND resource.labels.database_id = \"${data.google_client_config.current.project}:${module.database.instance_name}\" AND metric.type = \"cloudsql.googleapis.com/database/cpu/utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      duration        = "900s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = var.notification_channels
}
