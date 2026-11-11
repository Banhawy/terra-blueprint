mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}

mock_provider "aws" {
  alias = "us_east_1"
}

variables {
  name        = "acme-test-static-site"
  domain_name = "app.test.example.com"
}

run "private_origin_and_modern_tls" {
  command = plan

  assert {
    condition     = aws_cloudfront_origin_access_control.this.signing_behavior == "always"
    error_message = "CloudFront must sign every request to the private bucket (OAC)."
  }

  assert {
    condition     = one(aws_cloudfront_distribution.this.viewer_certificate).minimum_protocol_version == "TLSv1.2_2021"
    error_message = "Viewers must use TLS 1.2 or newer."
  }

  assert {
    condition     = one(aws_cloudfront_distribution.this.default_cache_behavior).viewer_protocol_policy == "redirect-to-https"
    error_message = "Plain HTTP must redirect to HTTPS."
  }
}

run "no_api_origin_by_default" {
  command = plan

  assert {
    condition     = length(aws_cloudfront_distribution.this.ordered_cache_behavior) == 1
    error_message = "Only the /assets/* behavior exists unless api_origin_domain is set."
  }
}

run "api_proxy_when_configured" {
  command = plan

  variables {
    api_origin_domain = "api.test.example.com"
  }

  assert {
    condition     = length(aws_cloudfront_distribution.this.ordered_cache_behavior) == 2
    error_message = "Setting api_origin_domain adds a cache behavior for the API."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.ordered_cache_behavior[1].path_pattern == "/api/*"
    error_message = "The API must be served under /api/*."
  }
}

run "deploy_role_is_optional" {
  command = plan

  assert {
    condition     = output.deploy_role_arn == null
    error_message = "No deploy role unless deploy_role is set."
  }
}

# The deploy role's policy JSON is only computed during apply; this proves the
# role and its policy can still be planned (for_each keys are static).
run "deploy_role_for_frontend_ci" {
  command = plan

  variables {
    deploy_role = {
      oidc_provider_arn = "arn:aws:iam::111111111111:oidc-provider/token.actions.githubusercontent.com"
      subjects          = ["repo:acme/web-frontend:environment:staging"]
    }
  }

  assert {
    condition     = length(module.deploy_role) == 1
    error_message = "Setting deploy_role must create the frontend deploy role."
  }
}
