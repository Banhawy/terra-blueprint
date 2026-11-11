variable "domain_name" {
  type        = string
  description = "Primary domain, e.g. \"staging.example.com\" or \"*.staging.example.com\"."
}

variable "subject_alternative_names" {
  type        = list(string)
  description = "Additional names on the same certificate, e.g. [\"*.staging.example.com\"]."
  default     = []
}

variable "route53_zone_id" {
  type        = string
  description = "Route 53 hosted zone to create validation records in. Null = output the records for manual creation."
  default     = null
}
