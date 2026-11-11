output "vpc_id" {
  value       = aws_vpc.this.id
  description = "VPC ID."
}

output "vpc_cidr" {
  value       = aws_vpc.this.cidr_block
  description = "VPC CIDR block."
}

output "azs" {
  value       = local.azs
  description = "Availability zones in use."
}

output "public_subnet_ids" {
  value       = [for s in aws_subnet.public : s.id]
  description = "Public subnet IDs (load balancers, NAT)."
}

output "private_subnet_ids" {
  value       = [for s in aws_subnet.private : s.id]
  description = "Private subnet IDs (compute)."
}

output "database_subnet_ids" {
  value       = [for s in aws_subnet.database : s.id]
  description = "Isolated subnet IDs (databases, caches)."
}

output "private_route_table_ids" {
  value       = [for rt in aws_route_table.private : rt.id]
  description = "Private route table IDs, for adding peering or VPN routes."
}

output "nat_public_ips" {
  value       = [for e in aws_eip.nat : e.public_ip]
  description = "Egress IPs of the NAT gateways -- give these to partners who allowlist your traffic."
}
