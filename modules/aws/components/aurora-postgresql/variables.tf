variable "name" {
  type        = string
  description = "Cluster identifier and prefix for related resources."
}

variable "database_name" {
  type        = string
  description = "Initial database created in the cluster."
}

variable "master_username" {
  type        = string
  description = "Master username. Its password is managed by RDS in Secrets Manager."
  default     = "postgres"
}

variable "vpc_id" {
  type        = string
  description = "VPC for the cluster's security group."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Isolated (database-tier) subnets, at least two AZs."
}

variable "allowed_security_group_ids" {
  type        = list(string)
  description = "Security groups allowed to connect on 5432."
  default     = []
}

variable "engine_version_prefix" {
  type        = string
  description = "Major or major.minor version; the newest matching engine version is selected at creation."
  default     = "17"
}

variable "min_capacity" {
  type        = number
  description = "Minimum Aurora capacity units. 0 lets an idle cluster pause (auto-pause) at the cost of a cold start."
  default     = 0.5
}

variable "max_capacity" {
  type        = number
  description = "Maximum Aurora capacity units."
  default     = 4
}

variable "instance_count" {
  type        = number
  description = "Cluster instances. 1 = writer only; 2+ adds readers that double as failover targets."
  default     = 1
}

variable "backup_retention_period" {
  type        = number
  description = "Days of automated backups (point-in-time recovery window)."
  default     = 7
}

variable "deletion_protection" {
  type        = bool
  description = "Block deletion and take a final snapshot on destroy. Enable in production."
  default     = false
}

variable "kms_key_arn" {
  type        = string
  description = "Optional customer-managed KMS key for storage encryption. Null uses the AWS-managed aws/rds key."
  default     = null
}

variable "performance_insights_enabled" {
  type        = bool
  description = "Enable Performance Insights (7 days retention is free)."
  default     = true
}
