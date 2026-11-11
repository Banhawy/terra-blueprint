# DNS-validated certificate. With a Route 53 zone the validation records are
# created and the module waits until the certificate is ISSUED; without one,
# the records are output so they can be added at whichever DNS provider you use.
resource "aws_acm_certificate" "this" {
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  manage_dns = var.route53_zone_id != null

  validation_records = {
    for o in aws_acm_certificate.this.domain_validation_options : o.domain_name => {
      name  = o.resource_record_name
      type  = o.resource_record_type
      value = o.resource_record_value
    }
  }
}

resource "aws_route53_record" "validation" {
  # Wildcard and apex share one validation record; dedupe by record name.
  for_each = local.manage_dns ? { for r in values(local.validation_records) : r.name => r... } : {}

  zone_id         = var.route53_zone_id
  name            = each.value[0].name
  type            = each.value[0].type
  records         = [each.value[0].value]
  ttl             = 300
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "this" {
  count = local.manage_dns ? 1 : 0

  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for r in aws_route53_record.validation : r.fqdn]
}
