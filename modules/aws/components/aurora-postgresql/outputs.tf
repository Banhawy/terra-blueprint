output "cluster_endpoint" {
  value       = aws_rds_cluster.this.endpoint
  description = "Writer endpoint."
}

output "reader_endpoint" {
  value       = aws_rds_cluster.this.reader_endpoint
  description = "Load-balanced reader endpoint."
}

output "port" {
  value       = aws_rds_cluster.this.port
  description = "Port the cluster listens on."
}

output "database_name" {
  value       = aws_rds_cluster.this.database_name
  description = "Initial database name."
}

output "master_username" {
  value       = aws_rds_cluster.this.master_username
  description = "Master username."
}

output "master_user_secret_arn" {
  value       = aws_rds_cluster.this.master_user_secret[0].secret_arn
  description = "Secrets Manager secret holding the RDS-managed master credentials."
}

output "cluster_resource_id" {
  value       = aws_rds_cluster.this.cluster_resource_id
  description = "Immutable resource ID used to scope rds-db:connect IAM policies."
}

output "cluster_identifier" {
  value       = aws_rds_cluster.this.cluster_identifier
  description = "Cluster identifier (the DBClusterIdentifier CloudWatch dimension)."
}

output "security_group_id" {
  value       = aws_security_group.this.id
  description = "Cluster security group."
}
