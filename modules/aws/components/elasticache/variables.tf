variable "name" {
  type        = string
  description = "Replication group ID and prefix for related resources (max 40 characters)."
}

variable "vpc_id" {
  type        = string
  description = "VPC for the cache's security group."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Isolated (database-tier) subnets."
}

variable "allowed_security_group_ids" {
  type        = list(string)
  description = "Security groups allowed to connect on 6379."
  default     = []
}

variable "node_type" {
  type        = string
  description = "Node type."
  default     = "cache.t4g.micro"
}

variable "node_count" {
  type        = number
  description = "Nodes in the group. 1 for staging; 2+ enables a replica with automatic Multi-AZ failover."
  default     = 1
}

variable "engine_version" {
  type        = string
  description = "Valkey engine version (major.minor)."
  default     = "8.0"
}

variable "snapshot_retention_limit" {
  type        = number
  description = "Days of automatic snapshots. 0 disables them (fine for a pure cache)."
  default     = 0
}

variable "kms_key_arn" {
  type        = string
  description = "Optional customer-managed KMS key for at-rest encryption."
  default     = null
}
