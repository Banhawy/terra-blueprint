# -----------------------------------------------------------------------------
# EC2 Auto Scaling group behind a launch template
#
# Secure-by-default instances: IMDSv2 only, encrypted root volume, no SSH key
# and no inbound rules -- shell access is via SSM Session Manager. Scaling is
# left to the caller: this module exposes simple scale-out / scale-in policies
# whose ARNs a CloudWatch alarm (e.g. on queue depth) can trigger.
# -----------------------------------------------------------------------------

# Latest AMI from an AWS-published SSM parameter (Amazon Linux 2023 by default).
# Resolved at plan time, so a new AMI shows up as a launch-template change and
# rolls the group through instance refresh on the next apply -- patching by apply.
data "aws_ssm_parameter" "ami" {
  name = var.ami_ssm_parameter
}

# Provider default_tags do not reach instances an ASG launches, so copy them
# onto the launch template's tag specifications explicitly.
data "aws_default_tags" "current" {}

locals {
  instance_tags = merge(data.aws_default_tags.current.tags, { Name = var.name })
}

# --- IAM ---------------------------------------------------------------------

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(concat([
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore", # Session Manager instead of SSH
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",  # ship logs and metrics
  ], var.additional_policy_arns))

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "this" {
  name = var.name
  role = aws_iam_role.this.name
}

# --- Networking --------------------------------------------------------------

resource "aws_security_group" "this" {
  name        = "${var.name}-instance"
  description = "Instances of ${var.name}"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-instance" }

  lifecycle {
    create_before_destroy = true
  }
}

#trivy:ignore:AVD-AWS-0104 -- instances pull packages and call AWS/third-party APIs; egress leaves via NAT.
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  description       = "All outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# --- Launch template and group -----------------------------------------------

resource "aws_launch_template" "this" {
  name_prefix   = "${var.name}-"
  image_id      = nonsensitive(data.aws_ssm_parameter.ami.value)
  instance_type = var.instance_type
  user_data     = var.user_data == null ? null : base64gzip(var.user_data)

  vpc_security_group_ids               = [aws_security_group.this.id]
  instance_initiated_shutdown_behavior = "terminate"

  iam_instance_profile {
    arn = aws_iam_instance_profile.this.arn
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 2          # allows containers on the host to reach IMDS
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.kms_key_arn
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = var.detailed_monitoring
  }

  tag_specifications {
    resource_type = "instance"
    tags          = local.instance_tags
  }

  tag_specifications {
    resource_type = "volume"
    tags          = local.instance_tags
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "this" {
  name                = var.name
  vpc_zone_identifier = var.subnet_ids
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.min_size

  health_check_type         = "EC2"
  health_check_grace_period = 300
  default_instance_warmup   = 120

  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }

  # A changed launch template (new AMI, user data, worker code hash) replaces
  # instances gradually. Instances protected from scale-in -- i.e. mid-job --
  # are waited for rather than killed.
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage       = var.instance_refresh_min_healthy_percentage
      scale_in_protected_instances = "Wait"
    }
  }

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]

  dynamic "tag" {
    for_each = local.instance_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = false # instances are tagged by the launch template
    }
  }

  lifecycle {
    # Scaling policies own the running count once the group exists.
    ignore_changes = [desired_capacity]
  }
}

# --- Scaling policies --------------------------------------------------------
# Simple step policies the caller wires to alarms of its choosing.

resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.name}-scale-out"
  autoscaling_group_name = aws_autoscaling_group.this.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = var.scale_out_step
  cooldown               = var.scaling_cooldown_seconds
}

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${var.name}-scale-in"
  autoscaling_group_name = aws_autoscaling_group.this.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = var.scaling_cooldown_seconds
}
