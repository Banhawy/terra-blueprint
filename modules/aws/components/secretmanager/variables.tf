variable "name_prefix" {
  type        = string
  description = "Path-style prefix for secret names, e.g. acme-staging/web-api. Secrets become <prefix>/<key>."
}

variable "secrets" {
  description = "Secrets to create, keyed by short name."
  type = map(object({
    description = string
  }))
  default = {}
}

variable "kms_key_arn" {
  type        = string
  description = "Optional customer-managed KMS key. Null uses the AWS-managed aws/secretsmanager key."
  default     = null
}

variable "recovery_window_in_days" {
  type        = number
  description = "Days a deleted secret stays recoverable (7-30), or 0 to delete immediately. Keep >0 outside throwaway environments."
  default     = 7

  validation {
    condition     = var.recovery_window_in_days == 0 || (var.recovery_window_in_days >= 7 && var.recovery_window_in_days <= 30)
    error_message = "recovery_window_in_days must be 0 or between 7 and 30."
  }
}
