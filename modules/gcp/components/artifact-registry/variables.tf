variable "name" {
  type        = string
  description = "Repository ID, e.g. acme-staging."
}

variable "region" {
  type        = string
  description = "Repository location (a region keeps pulls fast and in-region)."
}

variable "description" {
  type        = string
  description = "Repository description."
  default     = "Container images"
}

variable "keep_recent_versions" {
  type        = number
  description = "Versions per image always kept, regardless of age."
  default     = 50
}

variable "untagged_expiry_days" {
  type        = number
  description = "Days before untagged images are deleted."
  default     = 7
}
