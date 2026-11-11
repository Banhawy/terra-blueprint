variable "name" {
  type        = string
  description = "Load balancer name (max 32 characters), e.g. acme-staging-web-api."

  validation {
    condition     = length(var.name) <= 32
    error_message = "ALB names are limited to 32 characters."
  }
}

variable "vpc_id" {
  type        = string
  description = "VPC to create the security group in."
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR; the ALB's egress is limited to it."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets for the load balancer -- public subnets for an internet-facing ALB, at least two AZs."
}

variable "internal" {
  type        = bool
  description = "true for an internal (VPC-only) load balancer."
  default     = false
}

variable "ingress_cidr_blocks" {
  type        = list(string)
  description = "CIDRs allowed to reach ports 80/443."
  default     = ["0.0.0.0/0"]
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate for the HTTPS listener."
}

variable "ssl_policy" {
  type        = string
  description = "TLS policy. The default allows TLS 1.2 and 1.3 only."
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "idle_timeout" {
  type        = number
  description = "Seconds a connection may be idle. Raise it for long-polling or WebSockets."
  default     = 60
}

variable "deletion_protection" {
  type        = bool
  description = "Prevent the load balancer from being deleted (including by terraform destroy)."
  default     = false
}

variable "access_logs_bucket" {
  type        = string
  description = "Optional S3 bucket for access logs. The bucket policy must allow the regional ELB log-delivery principal."
  default     = null
}
