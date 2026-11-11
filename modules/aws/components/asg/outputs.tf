output "asg_name" {
  value       = aws_autoscaling_group.this.name
  description = "Auto Scaling group name."
}

output "asg_arn" {
  value       = aws_autoscaling_group.this.arn
  description = "Auto Scaling group ARN (scope autoscaling:SetInstanceProtection to it)."
}

output "role_name" {
  value       = aws_iam_role.this.name
  description = "Instance role -- attach application permissions to it."
}

output "role_arn" {
  value       = aws_iam_role.this.arn
  description = "Instance role ARN."
}

output "security_group_id" {
  value       = aws_security_group.this.id
  description = "Instance security group."
}

output "scale_out_policy_arn" {
  value       = aws_autoscaling_policy.scale_out.arn
  description = "Wire an alarm's alarm_actions to this to add capacity."
}

output "scale_in_policy_arn" {
  value       = aws_autoscaling_policy.scale_in.arn
  description = "Wire an alarm's alarm_actions to this to remove capacity."
}

output "launch_template_id" {
  value       = aws_launch_template.this.id
  description = "Launch template ID."
}
