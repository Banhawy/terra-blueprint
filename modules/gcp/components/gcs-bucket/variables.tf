variable "name" {
  type        = string
  description = "Globally unique bucket name."
}

variable "location" {
  type        = string
  description = "Region (or multi-region) for the bucket."
}

variable "force_destroy" {
  type        = bool
  description = "Allow destroying a non-empty bucket."
  default     = false
}

variable "versioning_enabled" {
  type        = bool
  description = "Keep previous object versions."
  default     = true
}

variable "noncurrent_version_expiration_days" {
  type        = number
  description = "Delete previous versions after this many days. Null keeps them forever."
  default     = 30
}

variable "expiration_days" {
  type        = number
  description = "Delete objects after this many days. Null keeps them."
  default     = null
}

variable "cors_origins" {
  type        = list(string)
  description = "Browser origins allowed to upload with signed URLs."
  default     = []
}

variable "kms_key_name" {
  type        = string
  description = "Optional Cloud KMS key for CMEK. Null uses Google-managed encryption."
  default     = null
}
