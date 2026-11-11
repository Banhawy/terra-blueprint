# Creates secret *containers* only. Values are set out of band
# (console, `aws secretsmanager put-secret-value`, or a rotation Lambda) so
# they never pass through Terraform state or code review.
resource "aws_secretsmanager_secret" "this" {
  for_each = var.secrets

  name                    = "${var.name_prefix}/${each.key}"
  description             = each.value.description
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.recovery_window_in_days
}
