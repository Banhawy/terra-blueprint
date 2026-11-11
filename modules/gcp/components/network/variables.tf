variable "name" {
  type        = string
  description = "Network name and prefix for its resources, e.g. acme-staging."
}

variable "region" {
  type        = string
  description = "Region for the subnet, router and NAT."
}

variable "cidr" {
  type        = string
  description = "Address space to carve the subnet and the Private Services Access range from. /16 recommended."

  validation {
    condition     = can(cidrhost(var.cidr, 0)) && tonumber(split("/", var.cidr)[1]) <= 18
    error_message = "cidr must be a valid IPv4 CIDR of /18 or larger."
  }
}

variable "enable_flow_logs" {
  type        = bool
  description = "Sample VPC flow logs on the subnet."
  default     = false
}
