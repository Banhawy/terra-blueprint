variable "name" {
  type        = string
  description = "Log group name, e.g. /ecs/acme-staging-web-api."
}

variable "retention_in_days" {
  type        = number
  description = "Days to keep log events. 0 means never expire -- avoid it, logs are a cost line that only grows."
  default     = 30

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.retention_in_days)
    error_message = "retention_in_days must be one of the values CloudWatch Logs accepts."
  }
}

variable "kms_key_arn" {
  type        = string
  description = "Optional customer-managed KMS key for the log group. Null uses CloudWatch's service-owned key."
  default     = null
}

variable "log_group_class" {
  type        = string
  description = "STANDARD, or INFREQUENT_ACCESS for logs that are rarely queried (cheaper ingestion, no metric filters)."
  default     = "STANDARD"
}
