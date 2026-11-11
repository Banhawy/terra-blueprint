# -----------------------------------------------------------------------------
# Three-tier VPC
#
#   public    ALB, NAT gateways                 route 0.0.0.0/0 -> internet gateway
#   private   ECS tasks, EC2 workers, Lambdas   route 0.0.0.0/0 -> NAT gateway
#   database  Aurora, ElastiCache               no internet route at all
#
# Address plan inside the VPC CIDR (shown for a /16):
#   public    /24s at 10.x.0.0, 10.x.1.0, ...       (small: only LBs and NATs)
#   private   /20s at 10.x.16.0, 10.x.32.0, ...     (large: one IP per Fargate task)
#   database  /24s at 10.x.128.0, 10.x.129.0, ...
# -----------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_region" "current" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  public_subnets   = { for i, az in local.azs : az => cidrsubnet(var.cidr, 8, i) }
  private_subnets  = { for i, az in local.azs : az => cidrsubnet(var.cidr, 4, i + 1) }
  database_subnets = { for i, az in local.azs : az => cidrsubnet(var.cidr, 8, 128 + i) }

  # One NAT gateway in the first AZ (cheap, single point of failure) or one per
  # AZ (each private subnet egresses through its own AZ's NAT).
  nat_azs = var.single_nat_gateway ? [local.azs[0]] : local.azs
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = var.name }
}

# Strip every rule from the default security group so nothing can use it by
# accident; resources get purpose-built groups instead.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name}-default-unused" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = var.name }
}

# --- Subnets -----------------------------------------------------------------

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = { Name = "${var.name}-public-${each.key}", Tier = "public" }
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = { Name = "${var.name}-private-${each.key}", Tier = "private" }
}

resource "aws_subnet" "database" {
  for_each = local.database_subnets

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = { Name = "${var.name}-database-${each.key}", Tier = "database" }
}

# --- NAT ---------------------------------------------------------------------

resource "aws_eip" "nat" {
  for_each = toset(local.nat_azs)
  domain   = "vpc"

  tags = { Name = "${var.name}-nat-${each.key}" }
}

resource "aws_nat_gateway" "this" {
  for_each = toset(local.nat_azs)

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = { Name = "${var.name}-${each.key}" }

  depends_on = [aws_internet_gateway.this]
}

# --- Routing -----------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = { Name = "${var.name}-public" }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  for_each = toset(local.azs)
  vpc_id   = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[var.single_nat_gateway ? local.azs[0] : each.key].id
  }

  tags = { Name = "${var.name}-private-${each.key}" }
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# Database subnets only ever talk to the VPC itself.
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name}-database" }
}

resource "aws_route_table_association" "database" {
  for_each       = aws_subnet.database
  subnet_id      = each.value.id
  route_table_id = aws_route_table.database.id
}

# --- VPC endpoints -----------------------------------------------------------

# Gateway endpoints are free: S3 traffic (ECR image layers, app buckets) stays
# on the AWS network instead of paying NAT data-processing charges.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat([for rt in aws_route_table.private : rt.id], [aws_route_table.database.id])

  tags = { Name = "${var.name}-s3" }
}

# Interface endpoints cost per AZ-hour, so they are opt-in. They keep image
# pulls, logs and secret reads off the NAT gateway and inside the VPC.
resource "aws_security_group" "endpoints" {
  count = var.enable_interface_endpoints ? 1 : 0

  name        = "${var.name}-vpc-endpoints"
  description = "HTTPS from inside the VPC to interface endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from the VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.cidr]
  }

  tags = { Name = "${var.name}-vpc-endpoints" }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = var.enable_interface_endpoints ? var.interface_endpoint_services : toset([])

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.private : s.id]
  security_group_ids  = [aws_security_group.endpoints[0].id]
  private_dns_enabled = true

  tags = { Name = "${var.name}-${each.value}" }
}

# --- Flow logs ---------------------------------------------------------------

module "flow_logs_group" {
  count  = var.enable_flow_logs ? 1 : 0
  source = "../cloudwatch/log-group"

  name              = "/vpc/${var.name}/flow-logs"
  retention_in_days = var.flow_logs_retention_in_days
}

data "aws_iam_policy_document" "flow_logs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name               = "${var.name}-vpc-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume.json
}

data "aws_iam_policy_document" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["${module.flow_logs_group[0].arn}:*"]
  }
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  role   = aws_iam_role.flow_logs[0].id
  policy = data.aws_iam_policy_document.flow_logs[0].json
}

resource "aws_flow_log" "this" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = module.flow_logs_group[0].arn
  iam_role_arn         = aws_iam_role.flow_logs[0].arn

  tags = { Name = var.name }
}
