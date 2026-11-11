output "primary_endpoint" {
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
  description = "Primary endpoint address."
}

output "port" {
  value       = aws_elasticache_replication_group.this.port
  description = "Port."
}

output "replication_group_id" {
  value       = aws_elasticache_replication_group.this.id
  description = "Replication group ID (the CacheClusterId CloudWatch dimension prefix)."
}

output "security_group_id" {
  value       = aws_security_group.this.id
  description = "Cache security group."
}
