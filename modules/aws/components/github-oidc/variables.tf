variable "name_prefix" {
  type        = string
  description = "Prefix for role names; roles are <prefix>-<key>."
}

variable "create_oidc_provider" {
  type        = bool
  description = "Create the account's GitHub OIDC provider. Only one may exist per account."
  default     = true
}

variable "oidc_provider_arn" {
  type        = string
  description = "Existing provider ARN when create_oidc_provider = false."
  default     = null
}

variable "roles" {
  description = <<-EOT
    Roles GitHub Actions may assume, keyed by short name. `subjects` are
    patterns matched against the token's `sub` claim, e.g.
      "repo:acme/infrastructure:environment:staging"
      "repo:acme/infrastructure:pull_request"
      "repo:acme/web-frontend:ref:refs/heads/main"
    Prefer `environment:<name>` subjects: GitHub Environments add required
    reviewers and branch rules on top of the IAM trust.
  EOT
  type = map(object({
    description          = string
    subjects             = list(string)
    managed_policy_arns  = optional(list(string), [])
    inline_policies      = optional(map(string), {})
    max_session_duration = optional(number, 3600)
  }))
  default = {}

  validation {
    condition     = alltrue([for r in values(var.roles) : length(r.subjects) > 0 && alltrue([for s in r.subjects : startswith(s, "repo:")])])
    error_message = "Every role needs at least one subject, and subjects must start with \"repo:\" -- an unscoped trust would let any GitHub repository assume the role."
  }
}
