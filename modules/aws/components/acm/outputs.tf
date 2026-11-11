output "certificate_arn" {
  # When DNS is managed here, return the ARN only once validation has finished,
  # so listeners and distributions never reference a PENDING certificate.
  value       = local.manage_dns ? aws_acm_certificate_validation.this[0].certificate_arn : aws_acm_certificate.this.arn
  description = "Certificate ARN."
}

output "validation_records" {
  value       = local.validation_records
  description = "DNS records that prove domain ownership. Create these by hand when route53_zone_id is null."
}
