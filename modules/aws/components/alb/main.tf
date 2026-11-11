# -----------------------------------------------------------------------------
# Application Load Balancer, shareable by several services.
#
# The load balancer owns TLS termination and an HTTP->HTTPS redirect. Its
# HTTPS listener answers 404 by default; each service attaches its own target
# group with an aws_lb_listener_rule (host- and/or path-based), so adding a
# second service never touches this module.
# -----------------------------------------------------------------------------

resource "aws_security_group" "this" {
  name        = "${var.name}-alb"
  description = "Load balancer ${var.name}"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-alb" }

  lifecycle {
    create_before_destroy = true
  }
}

# Public by design: the load balancer must accept HTTP(S) from the internet; WAF filters it.
resource "aws_vpc_security_group_ingress_rule" "http" {
  for_each = toset(var.ingress_cidr_blocks)

  security_group_id = aws_security_group.this.id
  description       = "HTTP (redirected to HTTPS)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = each.value
}

# Public by design: the load balancer must accept HTTP(S) from the internet; WAF filters it.
resource "aws_vpc_security_group_ingress_rule" "https" {
  for_each = toset(var.ingress_cidr_blocks)

  security_group_id = aws_security_group.this.id
  description       = "HTTPS"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = each.value
}

# The ALB only ever talks to targets inside the VPC.
resource "aws_vpc_security_group_egress_rule" "to_vpc" {
  security_group_id = aws_security_group.this.id
  description       = "To targets inside the VPC"
  ip_protocol       = "-1"
  cidr_ipv4         = var.vpc_cidr
}

#trivy:ignore:AVD-AWS-0053 -- internet-facing by design when var.internal = false.
resource "aws_lb" "this" {
  name               = var.name
  load_balancer_type = "application"
  internal           = var.internal
  subnets            = var.subnet_ids
  security_groups    = [aws_security_group.this.id]
  idle_timeout       = var.idle_timeout

  drop_invalid_header_fields = true
  enable_deletion_protection = var.deletion_protection

  dynamic "access_logs" {
    for_each = var.access_logs_bucket == null ? [] : [1]
    content {
      bucket  = var.access_logs_bucket
      prefix  = var.name
      enabled = true
    }
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn
  ssl_policy        = var.ssl_policy

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not found"
      status_code  = "404"
    }
  }
}
