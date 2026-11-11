# With a Route 53 zone the API hostname is created here; otherwise the record
# to add at your DNS provider is in the `dns_records` output.

resource "aws_route53_record" "api" {
  count = var.route53_zone_id == null ? 0 : 1

  zone_id = var.route53_zone_id
  name    = var.hostname
  type    = "A"

  alias {
    name                   = module.alb.dns_name
    zone_id                = module.alb.zone_id
    evaluate_target_health = true
  }
}
