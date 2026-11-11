terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.72"
      # CloudFront certificates (and CLOUDFRONT-scope WAF) must live in us-east-1.
      # live/aws/root.hcl generates this aliased provider for every unit.
      configuration_aliases = [aws.us_east_1]
    }
  }
}
