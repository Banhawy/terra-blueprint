output "bucket_name" {
  value       = aws_s3_bucket.this.id
  description = "Bucket name."
}

output "bucket_arn" {
  value       = aws_s3_bucket.this.arn
  description = "Bucket ARN."
}

output "bucket_regional_domain_name" {
  value       = aws_s3_bucket.this.bucket_regional_domain_name
  description = "Regional REST endpoint -- the origin domain CloudFront uses with Origin Access Control."
}
