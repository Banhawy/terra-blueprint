variable "name" {
  type        = string
  description = "Name for the VPC and prefix for its resources, e.g. acme-staging."
}

variable "cidr" {
  type        = string
  description = "VPC CIDR. A /16 is recommended; /16 to /18 are accepted. Must not overlap any network you may ever peer with."

  validation {
    condition     = can(cidrhost(var.cidr, 0)) && tonumber(split("/", var.cidr)[1]) >= 16 && tonumber(split("/", var.cidr)[1]) <= 18
    error_message = "cidr must be a valid IPv4 CIDR between /16 and /18."
  }
}

variable "az_count" {
  type        = number
  description = "Number of availability zones to spread subnets across. 2 is the minimum for ALB and Aurora; 3 tolerates an AZ outage with headroom."
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 6
    error_message = "az_count must be between 2 and 6."
  }
}

variable "single_nat_gateway" {
  type        = bool
  description = "true = one NAT gateway shared by all AZs (~$35/month, an AZ outage cuts egress). false = one per AZ (production)."
  default     = false
}

variable "enable_interface_endpoints" {
  type        = bool
  description = "Create interface endpoints for interface_endpoint_services (~$7-8 per endpoint per AZ per month)."
  default     = false
}

variable "interface_endpoint_services" {
  type        = set(string)
  description = "Service suffixes for interface endpoints (com.amazonaws.<region>.<suffix>)."
  default     = ["ecr.api", "ecr.dkr", "logs", "secretsmanager", "sts"]
}

variable "enable_flow_logs" {
  type        = bool
  description = "Send VPC flow logs (all traffic) to CloudWatch Logs."
  default     = false
}

variable "flow_logs_retention_in_days" {
  type        = number
  description = "Retention for the flow-log group."
  default     = 90
}
