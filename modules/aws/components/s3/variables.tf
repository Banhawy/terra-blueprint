variable "bucket_name" {
  type        = string
  description = "Globally unique bucket name."
}

variable "force_destroy" {
  type        = bool
  description = "Allow `terraform destroy` to delete a non-empty bucket. Keep false for anything holding real data."
  default     = false
}

variable "versioning_enabled" {
  type        = bool
  description = "Keep previous object versions. Pair with a noncurrent_version_expiration_days lifecycle rule to bound cost."
  default     = true
}

variable "kms_key_arn" {
  type        = string
  description = "Customer-managed KMS key for SSE-KMS. Null uses SSE-S3 (AES256), which is free and adequate unless you need key-level access control or audit."
  default     = null
}

variable "lifecycle_rules" {
  description = "Lifecycle rules. prefix = \"\" applies to the whole bucket."
  type = list(object({
    id                                 = string
    prefix                             = optional(string, "")
    expiration_days                    = optional(number)
    noncurrent_version_expiration_days = optional(number)
  }))
  default = []
}

variable "cors_rules" {
  description = "CORS rules, e.g. to allow browser uploads via presigned URLs from your app's origin."
  type = list(object({
    allowed_headers = optional(list(string), ["*"])
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = optional(list(string), ["ETag"])
    max_age_seconds = optional(number, 3000)
  }))
  default = []
}

variable "additional_policy_json" {
  type        = string
  description = "Extra bucket policy statements (an aws_iam_policy_document JSON) merged with the TLS-only statement."
  default     = null
}
