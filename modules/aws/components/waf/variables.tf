variable "name" {
  type        = string
  description = "Name of the web ACL. Rule and metric names are derived from it."
}

variable "scope" {
  type        = string
  description = "REGIONAL for ALB/API Gateway/AppSync, CLOUDFRONT for distributions. CLOUDFRONT web ACLs must be created in us-east-1."
  default     = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL", "CLOUDFRONT"], var.scope)
    error_message = "scope must be REGIONAL or CLOUDFRONT."
  }
}

variable "default_action" {
  type        = string
  description = "What happens to a request no rule matched. 'allow' is the only sane choice for a public API; 'block' turns the ACL into an allowlist."
  default     = "allow"

  validation {
    condition     = contains(["allow", "block"], var.default_action)
    error_message = "default_action must be allow or block."
  }
}

# ---------------------------------------------------------------------------
# Rate-based rules
# ---------------------------------------------------------------------------
# Each entry becomes one aws_wafv2_web_acl rate_based_statement. WAF evaluates
# these on a sliding window and lags real traffic by up to ~30s, so treat the
# limits as flood protection, not as a quota mechanism -- per-tenant quotas
# belong in the application, which is the only layer that knows who is calling.
variable "rate_limit_rules" {
  description = <<-EOT
    Rate-based rules, evaluated in ascending `priority` order. Fields:
      name              - suffix for the rule and its CloudWatch metric
      priority          - evaluation order; lower wins, must be unique across all rules
      limit             - requests per aggregation window from one key before the action fires
      window_seconds    - sliding window: 60, 120, 300 or 600
      action            - "block" or "count" (count observes without rejecting)
      host_header       - optional; scopes the rule to one Host, e.g. a machine-to-machine API host
      path_prefix       - optional; scopes the rule to URIs starting with this prefix
      aggregate_on      - "ip" (peer address), "forwarded_ip" (X-Forwarded-For, correct behind
                          CloudFront), or "custom_header" to key on header_name instead
      header_name       - required when aggregate_on = "custom_header"; the API-key header
    A rule with both host_header and path_prefix requires both to match.
  EOT

  type = list(object({
    name           = string
    priority       = number
    limit          = number
    window_seconds = optional(number, 300)
    action         = optional(string, "block")
    host_header    = optional(string)
    path_prefix    = optional(string)
    aggregate_on   = optional(string, "ip")
    header_name    = optional(string)
  }))

  default = []

  validation {
    condition     = length(distinct([for r in var.rate_limit_rules : r.priority])) == length(var.rate_limit_rules)
    error_message = "rate_limit_rules priorities must be unique."
  }

  validation {
    condition     = alltrue([for r in var.rate_limit_rules : contains(["block", "count"], r.action)])
    error_message = "rate_limit_rules action must be block or count."
  }

  validation {
    condition     = alltrue([for r in var.rate_limit_rules : contains([60, 120, 300, 600], r.window_seconds)])
    error_message = "rate_limit_rules window_seconds must be 60, 120, 300 or 600."
  }

  # WAF's floor is 100 per window; anything lower is silently treated as 100,
  # so reject it here rather than let a 10 look like it is in effect.
  validation {
    condition     = alltrue([for r in var.rate_limit_rules : r.limit >= 100])
    error_message = "rate_limit_rules limit must be at least 100 (WAF's minimum for a rate-based statement)."
  }

  validation {
    condition     = alltrue([for r in var.rate_limit_rules : contains(["ip", "forwarded_ip", "custom_header"], r.aggregate_on)])
    error_message = "rate_limit_rules aggregate_on must be ip, forwarded_ip or custom_header."
  }

  validation {
    condition     = alltrue([for r in var.rate_limit_rules : r.aggregate_on != "custom_header" || try(r.header_name, null) != null])
    error_message = "rate_limit_rules entries with aggregate_on = custom_header must set header_name."
  }
}

# ---------------------------------------------------------------------------
# AWS managed rule groups
# ---------------------------------------------------------------------------
variable "managed_rule_groups" {
  description = <<-EOT
    AWS managed rule groups to attach, evaluated in ascending `priority` order.
    Set `count_only = true` to run a group in count mode -- always do this first
    for a new group: CommonRuleSet in particular has rules (SizeRestrictions_BODY,
    NoUserAgent_HEADER, CrossSiteScripting_BODY) that reject legitimate file
    uploads and API clients, and you want the metrics before the blocks.
    `excluded_rules` overrides individual rules inside an otherwise-blocking group
    to count.
  EOT

  type = list(object({
    name           = string
    vendor_name    = optional(string, "AWS")
    priority       = number
    count_only     = optional(bool, false)
    excluded_rules = optional(list(string), [])
  }))

  default = []

  validation {
    condition     = length(distinct([for g in var.managed_rule_groups : g.priority])) == length(var.managed_rule_groups)
    error_message = "managed_rule_groups priorities must be unique."
  }
}

# ---------------------------------------------------------------------------
# Association and logging
# ---------------------------------------------------------------------------
variable "associated_resource_arns" {
  type        = list(string)
  description = "ARNs to associate the web ACL with (ALBs, API Gateway stages). Leave empty for CLOUDFRONT scope -- a distribution references its web ACL from its own resource instead."
  default     = []
}

variable "logging_enabled" {
  type        = bool
  description = "Send matched-request logs to CloudWatch Logs. The log group name is forced to aws-waf-logs-<name>; WAF rejects any other prefix."
  default     = true
}

variable "log_retention_in_days" {
  type        = number
  description = "Retention for the WAF log group."
  default     = 30
}

variable "log_redacted_headers" {
  type        = list(string)
  description = "Header names whose values are redacted in the logs. Any header carrying a credential belongs here -- WAF logs full headers otherwise."
  default     = ["authorization", "cookie", "x-api-key"]
}

variable "log_filter_blocked_only" {
  type        = bool
  description = "Log only requests a rule blocked or counted, not every allowed request. Keeps volume (and cost) proportional to abuse rather than to traffic."
  default     = true
}
