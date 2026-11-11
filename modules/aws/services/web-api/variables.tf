# --- Identity and placement ----------------------------------------------------

variable "name" {
  type        = string
  description = "Service name and prefix for all its resources, e.g. acme-staging-web-api (max 32 characters: ALB limit)."

  validation {
    condition     = length(var.name) <= 32
    error_message = "name is used for the ALB and target group, which are limited to 32 characters."
  }
}

variable "vpc_id" {
  type        = string
  description = "VPC to deploy into."
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR (limits the ALB's egress)."
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Subnets for the load balancer."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Subnets for the tasks."
}

variable "database_subnet_ids" {
  type        = list(string)
  description = "Isolated subnets for the database and cache."
}

# --- HTTP ------------------------------------------------------------------------

variable "hostname" {
  type        = string
  description = "Public hostname of the API, e.g. api.staging.example.com. Requests for other hosts get a 404."
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate covering hostname."
}

variable "route53_zone_id" {
  type        = string
  description = "Hosted zone to create the hostname record in. Null = add the record from the dns_records output by hand."
  default     = null
}

variable "container_port" {
  type        = number
  description = "Port the application listens on (exported to it as PORT)."
  default     = 8000
}

variable "health_check_path" {
  type        = string
  description = "Path the load balancer polls; must return 200 without auth."
  default     = "/healthz"
}

variable "health_check_grace_period_seconds" {
  type        = number
  description = "Seconds after task start before failed health checks count. Cover migrations and warm-up."
  default     = 120
}

# --- Container ---------------------------------------------------------------------

variable "image_repository" {
  type        = string
  description = "Image repository URL (from the ecr unit)."
}

variable "image_tag" {
  type        = string
  description = "Image tag to deploy. Bumping it is a deploy."
}

variable "cpu" {
  type        = number
  description = "Task CPU units."
  default     = 512
}

variable "memory" {
  type        = number
  description = "Task memory (MiB)."
  default     = 1024
}

variable "min_capacity" {
  type        = number
  description = "Minimum running tasks."
  default     = 1
}

variable "max_capacity" {
  type        = number
  description = "Maximum running tasks under load."
  default     = 2
}

variable "extra_environment" {
  type        = map(string)
  description = "Additional plain environment variables for the application."
  default     = {}
}

variable "extra_secrets" {
  type        = map(string)
  description = "Additional env var -> Secrets Manager ARN mappings for secrets created elsewhere."
  default     = {}
}

variable "extra_secret_arns" {
  type        = list(string)
  description = "ARNs of the secrets referenced in extra_secrets, so the execution role can read them."
  default     = []
}

variable "app_secrets" {
  description = "Secrets created for the app (values set by hand). Key \"app-secret-key\" is exposed as env var APP_SECRET_KEY."
  type = map(object({
    description = string
  }))
  default = {
    app-secret-key = { description = "Application signing key" }
  }
}

# --- Data --------------------------------------------------------------------------

variable "db_name" {
  type        = string
  description = "Name of the application database."
  default     = "app"
}

variable "db_use_iam_auth" {
  type        = bool
  description = <<-EOT
    Connect with IAM database authentication (no password). Requires a one-time
    SQL step as the master user: CREATE USER <db_app_username>; GRANT rds_iam TO <db_app_username>;
    false = the app uses the RDS-managed master credentials from Secrets Manager.
  EOT
  default     = true
}

variable "db_app_username" {
  type        = string
  description = "Database user the application connects as when db_use_iam_auth is true."
  default     = "app"
}

variable "db_min_capacity" {
  type        = number
  description = "Minimum Aurora capacity units."
  default     = 0.5
}

variable "db_max_capacity" {
  type        = number
  description = "Maximum Aurora capacity units."
  default     = 4
}

variable "db_instance_count" {
  type        = number
  description = "Aurora instances (2+ adds a failover reader)."
  default     = 1
}

variable "cache_node_type" {
  type        = string
  description = "Valkey node type."
  default     = "cache.t4g.micro"
}

variable "cache_node_count" {
  type        = number
  description = "Valkey nodes (2+ adds a replica with automatic failover)."
  default     = 1
}

variable "uploads_cors_origins" {
  type        = list(string)
  description = "Browser origins allowed to upload straight to the bucket with presigned URLs, e.g. [\"https://app.example.com\"]."
  default     = []
}

variable "deletion_protection" {
  type        = bool
  description = "Protect the ALB and database from deletion, keep a final DB snapshot, and refuse to destroy a non-empty bucket."
  default     = false
}

# --- WAF ---------------------------------------------------------------------------

variable "waf_enabled" {
  type        = bool
  description = "Attach a WAF web ACL to the load balancer."
  default     = true
}

variable "waf_rate_limit_per_5min" {
  type        = number
  description = "Requests per 5 minutes from one IP before it is blocked."
  default     = 2000
}

variable "waf_managed_rule_groups" {
  description = "AWS managed rule groups. CommonRuleSet starts in count mode: watch its metrics before letting it block."
  type = list(object({
    name           = string
    vendor_name    = optional(string, "AWS")
    priority       = number
    count_only     = optional(bool, false)
    excluded_rules = optional(list(string), [])
  }))
  default = [
    { name = "AWSManagedRulesAmazonIpReputationList", priority = 10 },
    { name = "AWSManagedRulesKnownBadInputsRuleSet", priority = 20 },
    { name = "AWSManagedRulesCommonRuleSet", priority = 30, count_only = true },
  ]
}

# --- Alerting and jobs -----------------------------------------------------------

variable "alert_notifier_enabled" {
  type        = bool
  description = "Deploy the Lambda that forwards alerts to a chat webhook."
  default     = true
}

variable "alarm_cpu_threshold" {
  type        = number
  description = "Service CPU % that raises an alarm."
  default     = 85
}

variable "alarm_memory_threshold" {
  type        = number
  description = "Service memory % that raises an alarm."
  default     = 85
}

variable "alarm_5xx_threshold" {
  type        = number
  description = "5xx responses per 5 minutes that raise an alarm."
  default     = 10
}

variable "scheduled_tasks" {
  description = <<-EOT
    Jobs that run the service image on a schedule with a different command, e.g.
      cleanup = {
        description         = "Purge expired sessions"
        schedule_expression = "cron(0 3 * * ? *)"
        command             = ["python", "manage.py", "clearsessions"]
      }
  EOT
  type = map(object({
    description         = string
    schedule_expression = string
    command             = list(string)
    timezone            = optional(string, "UTC")
    enabled             = optional(bool, true)
  }))
  default = {}
}
