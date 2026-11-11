# static-site (AWS)

Hosting for a single-page app: a private S3 bucket served through CloudFront.

```
viewer ─> CloudFront (TLS 1.2+, security headers, SPA routing function)
            ├─ /assets/*  ─> S3 (OAC)   cached for a year (content-hashed files)
            ├─ /api/*     ─> web-api    optional same-origin proxy, never cached
            └─ default    ─> S3 (OAC)   index.html, always revalidated
```

- **Private bucket.** CloudFront signs every origin request with Origin Access
  Control; the bucket policy admits only this distribution.
- **Certificate in us-east-1.** CloudFront only accepts certificates from
  us-east-1, so the `acm` component is called with the `aws.us_east_1` provider
  that `live/aws/root.hcl` generates for every unit.
- **Same-origin API.** With `api_origin_domain` set, the browser calls `/api/*`
  on the site's own domain: no CORS, cookies stay first-party. The origin is
  the API's *hostname* (not the ALB DNS name) so its certificate validates.
- **CI deploy role.** `deploy_role` creates a role the frontend repository's
  pipeline assumes via GitHub OIDC. It may only sync the bucket and invalidate
  the distribution:
  ```sh
  aws s3 sync dist/ "s3://$BUCKET/" --delete
  aws cloudfront create-invalidation --distribution-id "$DISTRIBUTION_ID" --paths '/index.html'
  ```
- **Content-Security-Policy.** Not set by default because it is app-specific.
  Write one (`content_security_policy`); it is the strongest XSS defence a SPA has.

Without a Route 53 zone, the first apply creates the certificate and then fails
at the CloudFront distribution (CloudFront needs an issued certificate). Create
the certificate's validation CNAMEs (ACM console, region us-east-1), wait for it
to show ISSUED, and apply again. Then add the site CNAMEs from `dns_records`.

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.10 |
| aws | ~> 6.72 |

### Providers

| Name | Version |
| ---- | ------- |
| aws | ~> 6.72 |

### Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| bucket | ../../components/s3 | n/a |
| certificate | ../../components/acm | n/a |
| deploy\_role | ../../components/github-oidc | n/a |
| waf | ../../components/waf | n/a |

### Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudfront_distribution.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution) | resource |
| [aws_cloudfront_function.spa_router](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_function) | resource |
| [aws_cloudfront_origin_access_control.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_access_control) | resource |
| [aws_cloudfront_response_headers_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_response_headers_policy) | resource |
| [aws_route53_record.alias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_cloudfront_cache_policy.disabled](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudfront_cache_policy) | data source |
| [aws_cloudfront_cache_policy.optimized](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudfront_cache_policy) | data source |
| [aws_cloudfront_origin_request_policy.all_viewer_except_host](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudfront_origin_request_policy) | data source |
| [aws_iam_policy_document.deploy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.oac](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| domain\_name | Primary hostname, e.g. app.staging.example.com. | `string` | n/a | yes |
| name | Site name and prefix for its resources, e.g. acme-staging-static-site. | `string` | n/a | yes |
| additional\_domain\_names | Extra hostnames served by the same distribution (also added to the certificate). | `list(string)` | `[]` | no |
| api\_origin\_domain | Hostname of the API to proxy under api\_path\_pattern (its certificate must cover this name), e.g. api.staging.example.com. Null disables the proxy. | `string` | `null` | no |
| api\_path\_pattern | Path pattern routed to the API origin. | `string` | `"/api/*"` | no |
| content\_security\_policy | Content-Security-Policy header value. Null sends none -- write one for your app; it is the strongest XSS mitigation available. | `string` | `null` | no |
| deploy\_role | Create a CI deploy role for the frontend repository. subjects are GitHub OIDC `sub` patterns, e.g. ["repo:acme/web-frontend:environment:staging"]. | ```object({ oidc_provider_arn = string subjects = list(string) })``` | `null` | no |
| force\_destroy | Allow destroying the bucket while it still holds a build. | `bool` | `false` | no |
| price\_class | CloudFront edge coverage: PriceClass\_100 (NA+EU), PriceClass\_200, PriceClass\_All. | `string` | `"PriceClass_100"` | no |
| route53\_zone\_id | Hosted zone for certificate validation and alias records. Null = create the records in the dns\_records output by hand. | `string` | `null` | no |
| waf\_enabled | Attach a CLOUDFRONT-scope WAF (created in us-east-1). | `bool` | `false` | no |
| waf\_rate\_limit\_per\_5min | Requests per 5 minutes per IP before blocking, when the WAF is enabled. | `number` | `5000` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| bucket\_name | Bucket to upload the build to (aws s3 sync dist/ s3://<bucket>/ --delete). |
| deploy\_role\_arn | Role for the frontend pipeline to assume. |
| distribution\_domain\_name | CloudFront domain -- the CNAME target for the site's hostnames. |
| distribution\_id | Distribution ID (aws cloudfront create-invalidation --distribution-id <id> --paths '/*'). |
| dns\_records | Records to create at your DNS provider: site CNAMEs plus certificate validation (empty when Route 53 manages them). |
| url | Public URL of the site. |
<!-- END_TF_DOCS -->
