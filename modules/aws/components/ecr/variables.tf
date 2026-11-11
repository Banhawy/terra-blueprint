variable "repositories" {
  type        = set(string)
  description = "Repository names to create, e.g. [\"acme/web-api\"]."
}

variable "max_tagged_images" {
  type        = number
  description = "How many tagged images to keep per repository. Older ones are expired -- keep enough to roll back."
  default     = 50
}

variable "untagged_image_expiry_days" {
  type        = number
  description = "Days before untagged (superseded) images are expired."
  default     = 7
}

variable "kms_key_arn" {
  type        = string
  description = "Optional customer-managed KMS key. Null uses ECR's AES256 encryption."
  default     = null
}

variable "force_delete" {
  type        = bool
  description = "Allow destroying repositories that still contain images."
  default     = false
}
