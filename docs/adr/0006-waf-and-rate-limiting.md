# 0006. Rate limiting is split: WAF stops floods, the application enforces quotas

- Status: accepted

## Context

"Rate limit at the edge or in the app?" has no single answer. The two layers
can enforce different things, and neither can do the other's job.

## Decision

| | WAF (edge) | Application |
|---|---|---|
| Keyed on | source IP, or one header value | user, tenant, API key, endpoint |
| Enforces | flood ceilings, known-bad inputs, IP reputation | plans, quotas, per-endpoint costs |
| Response | opaque 403 | `429` + `Retry-After` |
| Cost of a rejection | ~nothing; never reaches compute | a task slot, usually a DB round trip |

- `web-api` attaches a regional WAF to its ALB with a per-IP rate rule (a
  backstop, well above any real client) and AWS managed rule groups.
- **New managed groups start in `count` mode.** `AWSManagedRulesCommonRuleSet`
  in particular has rules (`SizeRestrictions_BODY`, `CrossSiteScripting_BODY`)
  that reject legitimate uploads and API payloads. Watch the per-rule metrics,
  then switch it to block.
- Rate rules key on the **peer IP**, not `X-Forwarded-For`, unless a proxy you
  control overwrites that header. Otherwise any client can forge a fresh
  rate-limit bucket per request.
- Logs keep only blocked/counted requests and redact credential headers
  (`authorization`, `cookie`, `x-api-key`).

## Consequences

- A flood never reaches Fargate. Per-customer fairness is the application's job.
- Requests behind CloudFront (`/api/*` via static-site) reach the ALB from
  CloudFront's IPs, so the ALB's per-IP rule meters the edge, not the browser.
  Enable static-site's own CLOUDFRONT-scope WAF if that path needs per-viewer limits.
