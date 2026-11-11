# 0005. Static sites are served from a private bucket via CloudFront OAC

- Status: accepted

## Context

The classic setup, a public-read bucket with the S3 *website* endpoint behind
CloudFront, works, but the bucket is directly reachable. That bypasses
CloudFront and anything attached to it (WAF, headers, logging). It also forces
an `http-only` origin and cannot use SSE-KMS.

## Decision

- The bucket is private: all public-access blocks on, ACLs disabled
  (`BucketOwnerEnforced`), versioned, encrypted, TLS-only policy.
- CloudFront reads it through **Origin Access Control** (signed SigV4 requests
  to the S3 REST endpoint). The bucket policy admits only this distribution's ARN.
- SPA routing is a CloudFront Function, not an S3 error-document fallback. Real
  403s and 404s stay visible, and routes containing dots keep working.

## Consequences

- Deploy pipelines must not send object ACLs: ACLs are disabled, and
  `AccessControlListNotSupported` is the result.
- The bucket policy references the distribution and the distribution references
  the bucket. Terraform orders this correctly. Keep it that way when refactoring
  (the policy must not be passed into the bucket resource itself).
