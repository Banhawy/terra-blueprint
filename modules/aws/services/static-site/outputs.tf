output "url" {
  value       = "https://${var.domain_name}"
  description = "Public URL of the site."
}

output "bucket_name" {
  value       = module.bucket.bucket_name
  description = "Bucket to upload the build to (aws s3 sync dist/ s3://<bucket>/ --delete)."
}

output "distribution_id" {
  value       = aws_cloudfront_distribution.this.id
  description = "Distribution ID (aws cloudfront create-invalidation --distribution-id <id> --paths '/*')."
}

output "distribution_domain_name" {
  value       = aws_cloudfront_distribution.this.domain_name
  description = "CloudFront domain -- the CNAME target for the site's hostnames."
}

output "deploy_role_arn" {
  value       = try(module.deploy_role[0].role_arns["deploy"], null)
  description = "Role for the frontend pipeline to assume."
}

output "dns_records" {
  value = var.route53_zone_id != null ? [] : concat(
    [for name in local.aliases : { name = name, type = "CNAME", value = aws_cloudfront_distribution.this.domain_name }],
    [for r in values(module.certificate.validation_records) : { name = r.name, type = r.type, value = r.value }],
  )
  description = "Records to create at your DNS provider: site CNAMEs plus certificate validation (empty when Route 53 manages them)."
}
