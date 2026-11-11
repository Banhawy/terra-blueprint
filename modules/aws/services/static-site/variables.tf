variable "name" {
  type        = string
  description = "Site name and prefix for its resources, e.g. acme-staging-static-site."
}

variable "domain_name" {
  type        = string
  description = "Primary hostname, e.g. app.staging.example.com."
}

variable "additional_domain_names" {
  type        = list(string)
  description = "Extra hostnames served by the same distribution (also added to the certificate)."
  default     = []
}

variable "route53_zone_id" {
  type        = string
  description = "Hosted zone for certificate validation and alias records. Null = create the records in the dns_records output by hand."
  default     = null
}

variable "api_origin_domain" {
  type        = string
  description = "Hostname of the API to proxy under api_path_pattern (its certificate must cover this name), e.g. api.staging.example.com. Null disables the proxy."
  default     = null
}

variable "api_path_pattern" {
  type        = string
  description = "Path pattern routed to the API origin."
  default     = "/api/*"
}

variable "content_security_policy" {
  type        = string
  description = "Content-Security-Policy header value. Null sends none -- write one for your app; it is the strongest XSS mitigation available."
  default     = null
}

variable "price_class" {
  type        = string
  description = "CloudFront edge coverage: PriceClass_100 (NA+EU), PriceClass_200, PriceClass_All."
  default     = "PriceClass_100"
}

variable "waf_enabled" {
  type        = bool
  description = "Attach a CLOUDFRONT-scope WAF (created in us-east-1)."
  default     = false
}

variable "waf_rate_limit_per_5min" {
  type        = number
  description = "Requests per 5 minutes per IP before blocking, when the WAF is enabled."
  default     = 5000
}

variable "force_destroy" {
  type        = bool
  description = "Allow destroying the bucket while it still holds a build."
  default     = false
}

variable "deploy_role" {
  description = <<-EOT
    Create a CI deploy role for the frontend repository. subjects are GitHub
    OIDC `sub` patterns, e.g. ["repo:acme/web-frontend:environment:staging"].
  EOT
  type = object({
    oidc_provider_arn = string
    subjects          = list(string)
  })
  default = null
}
