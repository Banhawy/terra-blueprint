variable "pool_id" {
  type        = string
  description = "Workload identity pool ID. IDs are reserved for 30 days after deletion."
  default     = "github"
}

variable "github_org" {
  type        = string
  description = "GitHub organisation (or user) whose tokens are accepted."
}

variable "name_prefix" {
  type        = string
  description = "Prefix for service account IDs (<prefix>-<key>, max 30 characters in total)."
}

variable "service_accounts" {
  description = <<-EOT
    Service accounts GitHub Actions may impersonate. subjects are matched
    exactly against the token's `sub` claim, e.g.
      "repo:acme/infrastructure:environment:staging"
      "repo:acme/infrastructure:pull_request"
  EOT
  type = map(object({
    description   = string
    subjects      = list(string)
    project_roles = optional(list(string), [])
    # Bucket-scoped grants, e.g. object access to the state bucket only.
    bucket_roles = optional(list(object({
      bucket = string
      role   = string
    })), [])
  }))
  default = {}

  validation {
    condition     = alltrue([for sa in values(var.service_accounts) : length(sa.subjects) > 0 && alltrue([for s in sa.subjects : startswith(s, "repo:")])])
    error_message = "Every service account needs at least one subject starting with \"repo:\"."
  }
}
