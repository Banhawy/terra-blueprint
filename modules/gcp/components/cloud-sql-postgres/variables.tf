variable "name" {
  type        = string
  description = "Instance name. Cloud SQL reserves names for a week after deletion."
}

variable "region" {
  type        = string
  description = "Region."
}

variable "network_id" {
  type        = string
  description = "VPC network with Private Services Access already configured (network component)."
}

variable "database_version" {
  type        = string
  description = "PostgreSQL major version."
  default     = "POSTGRES_17"
}

variable "tier" {
  type        = string
  description = "Machine tier, e.g. db-custom-1-3840 (1 vCPU, 3.75 GB)."
  default     = "db-custom-1-3840"
}

variable "high_availability" {
  type        = bool
  description = "REGIONAL availability: a standby in another zone with automatic failover (doubles cost)."
  default     = false
}

variable "disk_size_gb" {
  type        = number
  description = "Initial disk size; grows automatically."
  default     = 10
}

variable "database_name" {
  type        = string
  description = "Application database."
  default     = "app"
}

variable "iam_service_account_emails" {
  type        = set(string)
  description = "Service accounts that get an IAM database user."
  default     = []
}

variable "backup_retention_count" {
  type        = number
  description = "Daily backups kept."
  default     = 7
}

variable "deletion_protection" {
  type        = bool
  description = "Block deletion (both Terraform-side and the Cloud SQL API flag)."
  default     = false
}
