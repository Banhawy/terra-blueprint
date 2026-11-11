output "arn" {
  value       = aws_lb.this.arn
  description = "Load balancer ARN (for WAF association)."
}

output "arn_suffix" {
  value       = aws_lb.this.arn_suffix
  description = "ARN suffix, used as the LoadBalancer dimension of CloudWatch metrics."
}

output "dns_name" {
  value       = aws_lb.this.dns_name
  description = "Load balancer DNS name -- the target of CNAME/alias records."
}

output "zone_id" {
  value       = aws_lb.this.zone_id
  description = "Canonical hosted zone ID, for Route 53 alias records."
}

output "security_group_id" {
  value       = aws_security_group.this.id
  description = "Load balancer security group; allow it on target security groups."
}

output "https_listener_arn" {
  value       = aws_lb_listener.https.arn
  description = "HTTPS listener; services attach aws_lb_listener_rule resources to it."
}
