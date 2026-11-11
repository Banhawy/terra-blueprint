# -----------------------------------------------------------------------------
# static-site: a single-page app on S3 + CloudFront
#
#   viewer -> CloudFront (TLS, security headers, SPA routing)
#               ├─ default     -> private S3 bucket via Origin Access Control
#               └─ /api/*      -> web-api load balancer   (optional, same origin)
#
# The bucket is never public: CloudFront signs every origin request (OAC) and
# the bucket policy only admits this one distribution.
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

locals {
  aliases       = concat([var.domain_name], var.additional_domain_names)
  s3_origin_id  = "s3"
  api_origin_id = "api"
  api_enabled   = var.api_origin_domain != null

  cache_headers = {
    # index.html and other unhashed files: always revalidate so a deploy is
    # visible immediately.
    shell = "no-cache"
    # Content-hashed build output (/assets/*): cache for a year.
    assets = "public, max-age=31536000, immutable"
  }
}

# --- Bucket -------------------------------------------------------------------

data "aws_iam_policy_document" "oac" {
  statement {
    sid       = "AllowCloudFrontRead"
    actions   = ["s3:GetObject"]
    resources = ["${module.bucket.bucket_arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

module "bucket" {
  source = "../../components/s3"

  bucket_name            = "${var.name}-${data.aws_caller_identity.current.account_id}"
  force_destroy          = var.force_destroy
  additional_policy_json = data.aws_iam_policy_document.oac.json
  lifecycle_rules = [{
    id                                 = "expire-old-versions"
    noncurrent_version_expiration_days = 30
  }]
}

# --- Certificate (us-east-1) ----------------------------------------------------

module "certificate" {
  source = "../../components/acm"
  providers = {
    aws = aws.us_east_1
  }

  domain_name               = var.domain_name
  subject_alternative_names = var.additional_domain_names
  route53_zone_id           = var.route53_zone_id
}

# --- Optional WAF (CLOUDFRONT scope, us-east-1) ------------------------------------

module "waf" {
  count  = var.waf_enabled ? 1 : 0
  source = "../../components/waf"
  providers = {
    aws = aws.us_east_1
  }

  name  = var.name
  scope = "CLOUDFRONT"
  managed_rule_groups = [
    { name = "AWSManagedRulesAmazonIpReputationList", priority = 10 },
    { name = "AWSManagedRulesKnownBadInputsRuleSet", priority = 20 },
  ]
  rate_limit_rules = [{
    name           = "per-ip"
    priority       = 100
    limit          = var.waf_rate_limit_per_5min
    aggregate_on   = "ip"
    window_seconds = 300
  }]
}

# --- CloudFront -------------------------------------------------------------------

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = var.name
  description                       = "Signed S3 origin requests for ${var.name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

resource "aws_cloudfront_response_headers_policy" "this" {
  for_each = local.cache_headers

  name    = "${var.name}-${each.key}"
  comment = "Cache-Control: ${each.value} plus security headers"

  custom_headers_config {
    items {
      header   = "Cache-Control"
      value    = each.value
      override = true
    }
    items {
      header   = "Permissions-Policy"
      value    = "camera=(), geolocation=(), microphone=(), payment=(), usb=()"
      override = true
    }
  }

  security_headers_config {
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      override                   = true
    }
    dynamic "content_security_policy" {
      for_each = var.content_security_policy == null ? [] : [1]
      content {
        content_security_policy = var.content_security_policy
        override                = true
      }
    }
  }
}

# SPA routing at the edge: anything that is not a known static-file extension
# (and not the API) is a client-side route and gets the app shell. Matching on
# extensions rather than "contains a dot" keeps routes like /reset/abc.def working.
resource "aws_cloudfront_function" "spa_router" {
  name    = "${var.name}-spa-router"
  runtime = "cloudfront-js-2.0"
  comment = "Serve /index.html for client-side routes"
  publish = true
  code    = <<-EOT
    var ASSET_EXTENSIONS = ['js', 'mjs', 'css', 'map', 'json', 'webmanifest', 'txt', 'xml', 'wasm',
      'ico', 'png', 'jpg', 'jpeg', 'gif', 'svg', 'webp', 'avif', 'mp4', 'webm', 'mp3',
      'woff', 'woff2', 'ttf', 'otf', 'pdf'];

    function handler(event) {
      var request = event.request;
      var uri = request.uri;
      if (uri.indexOf('${trimsuffix(var.api_path_pattern, "*")}') === 0) {
        return request;
      }
      var last = uri.substring(uri.lastIndexOf('/') + 1);
      var dot = last.lastIndexOf('.');
      if (dot !== -1 && ASSET_EXTENSIONS.indexOf(last.substring(dot + 1).toLowerCase()) !== -1) {
        return request;
      }
      request.uri = '/index.html';
      return request;
    }
  EOT
}

# Access logs need a log bucket per account: add `logging_config` once you have one.
# WAF is optional for a static site (var.waf_enabled); the API behind /api/* has its own.
resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  comment             = var.name
  default_root_object = "index.html"
  aliases             = local.aliases
  price_class         = var.price_class
  web_acl_id          = var.waf_enabled ? module.waf[0].web_acl_arn : null

  origin {
    origin_id                = local.s3_origin_id
    domain_name              = module.bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  dynamic "origin" {
    for_each = local.api_enabled ? [1] : []
    content {
      origin_id   = local.api_origin_id
      domain_name = var.api_origin_domain

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  default_cache_behavior {
    target_origin_id           = local.s3_origin_id
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.optimized.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.this["shell"].id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.spa_router.arn
    }
  }

  ordered_cache_behavior {
    path_pattern               = "/assets/*"
    target_origin_id           = local.s3_origin_id
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.optimized.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.this["assets"].id
  }

  # Same-origin API: the browser calls /api/* on the site's own domain, so no
  # CORS is needed. Nothing is cached and all viewer headers except Host are
  # forwarded -- the origin's certificate is validated against its own name.
  dynamic "ordered_cache_behavior" {
    for_each = local.api_enabled ? [1] : []
    content {
      path_pattern             = var.api_path_pattern
      target_origin_id         = local.api_origin_id
      viewer_protocol_policy   = "redirect-to-https"
      allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods           = ["GET", "HEAD"]
      compress                 = true
      cache_policy_id          = data.aws_cloudfront_cache_policy.disabled.id
      origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    }
  }

  viewer_certificate {
    acm_certificate_arn      = module.certificate.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

# --- DNS -----------------------------------------------------------------------------

resource "aws_route53_record" "alias" {
  for_each = var.route53_zone_id == null ? {} : { for pair in setproduct(local.aliases, ["A", "AAAA"]) : "${pair[0]}-${pair[1]}" => { name = pair[0], type = pair[1] } }

  zone_id = var.route53_zone_id
  name    = each.value.name
  type    = each.value.type

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

# --- Deploy role for the frontend's CI ---------------------------------------------
# The frontend repository's pipeline assumes this role (GitHub OIDC, no keys)
# to upload a build and invalidate the cache -- and can do nothing else.

data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "SyncBuild"
    actions   = ["s3:PutObject", "s3:DeleteObject", "s3:GetObject"]
    resources = ["${module.bucket.bucket_arn}/*"]
  }

  statement {
    sid       = "ListBucket"
    actions   = ["s3:ListBucket"]
    resources = [module.bucket.bucket_arn]
  }

  statement {
    sid       = "Invalidate"
    actions   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
    resources = [aws_cloudfront_distribution.this.arn]
  }
}

module "deploy_role" {
  count  = var.deploy_role == null ? 0 : 1
  source = "../../components/github-oidc"

  name_prefix          = var.name
  create_oidc_provider = false
  oidc_provider_arn    = var.deploy_role.oidc_provider_arn

  roles = {
    deploy = {
      description     = "CI deploys of ${var.name}: S3 sync + CloudFront invalidation"
      subjects        = var.deploy_role.subjects
      inline_policies = { deploy = data.aws_iam_policy_document.deploy.json }
    }
  }
}
