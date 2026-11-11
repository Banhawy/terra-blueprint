variable "name" {
  type        = string
  description = "Service name and prefix for its resources, e.g. acme-staging-web-api."
}

variable "region" {
  type        = string
  description = "Region for Cloud Run, Cloud SQL and the bucket."
}

variable "network_id" {
  type        = string
  description = "VPC network with Private Services Access (network unit)."
}

variable "subnet_id" {
  type        = string
  description = "Subnet for Cloud Run Direct VPC egress (network unit)."
}

variable "image_repository" {
  type        = string
  description = "Image path without tag, e.g. europe-west1-docker.pkg.dev/acme-staging/acme-staging/web-api."
}

variable "image_tag" {
  type        = string
  description = "Image tag to deploy. Bumping it is a deploy."
}

variable "container_port" {
  type        = number
  description = "Port the application listens on."
  default     = 8080
}

variable "health_check_path" {
  type        = string
  description = "Startup/liveness probe path."
  default     = "/healthz"
}

variable "min_instances" {
  type        = number
  description = "Warm instances (0 = scale to zero)."
  default     = 0
}

variable "max_instances" {
  type        = number
  description = "Maximum instances."
  default     = 3
}

variable "allow_unauthenticated" {
  type        = bool
  description = "Public API: anyone may invoke it (the app does its own auth)."
  default     = true
}

variable "extra_environment" {
  type        = map(string)
  description = "Additional plain environment variables."
  default     = {}
}

variable "app_secrets" {
  description = "Secrets for the app (values set by hand). Key \"app-secret-key\" is exposed as APP_SECRET_KEY."
  type = map(object({
    description = string
  }))
  default = {
    app-secret-key = { description = "Application signing key" }
  }
}

variable "db_name" {
  type        = string
  description = "Application database name."
  default     = "app"
}

variable "db_tier" {
  type        = string
  description = "Cloud SQL machine tier."
  default     = "db-custom-1-3840"
}

variable "db_high_availability" {
  type        = bool
  description = "Regional (HA) Cloud SQL instance."
  default     = false
}

variable "uploads_cors_origins" {
  type        = list(string)
  description = "Browser origins allowed to upload with signed URLs."
  default     = []
}

variable "deletion_protection" {
  type        = bool
  description = "Protect the service and database from deletion; refuse to destroy a non-empty bucket."
  default     = false
}

variable "notification_channels" {
  type        = list(string)
  description = "Cloud Monitoring notification channel IDs for alert policies (e-mail, Slack, PagerDuty)."
  default     = []
}

variable "alarm_5xx_per_minute" {
  type        = number
  description = "5xx responses per minute (sustained 5 minutes) that open an incident."
  default     = 1
}
