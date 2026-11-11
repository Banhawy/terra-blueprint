# Architecture Decision Records

Short records of decisions that are not obvious from the code: what was chosen,
what was rejected, and what must not be undone by accident. Copy
[`0000-template.md`](0000-template.md) for a new one. Number sequentially and
never renumber.

| # | Decision |
|---|---|
| [0001](0001-two-tier-modules.md) | Modules come in two tiers: components and services |
| [0002](0002-terragrunt-layout.md) | One root.hcl per cloud; settings cascade down the directory tree |
| [0003](0003-tags-via-provider.md) | Tags and labels come from the provider, not module variables |
| [0004](0004-keyless-ci.md) | CI authenticates with OIDC; no long-lived cloud credentials |
| [0005](0005-private-s3-with-oac.md) | Static sites are served from a private bucket via CloudFront OAC |
| [0006](0006-waf-and-rate-limiting.md) | Rate limiting is split: WAF stops floods, the application enforces quotas |
| [0007](0007-queue-workers-scale-in-protection.md) | Queue workers protect themselves from scale-in while busy |
