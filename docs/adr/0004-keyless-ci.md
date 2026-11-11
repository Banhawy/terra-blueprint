# 0004. CI authenticates with OIDC; no long-lived cloud credentials exist

- Status: accepted

## Context

Access keys and service-account key files stored as CI secrets do not expire,
are copied between systems, and leak. They are also the usual reason an IAM
user exists at all.

## Decision

- AWS: an IAM OIDC provider for GitHub plus roles (`github-oidc` component).
  GCP: a Workload Identity pool and provider plus service accounts
  (`workload-identity-federation` component).
- Each identity trusts an explicit list of token subjects:
  - plan identities: `repo:<org>/<repo>:pull_request`, read-only access plus
    the state bucket;
  - apply identities: `repo:<org>/<repo>:environment:<env>`, so GitHub
    Environment protections (required reviewers) gate production.
- Both components reject trust policies whose subjects do not start with
  `repo:` (validation + tests), so a typo cannot trust all of GitHub.
- The frontend's deploy role (S3 sync + CloudFront invalidation, nothing else)
  is created by `static-site` with the same component.
- No IAM users. Humans use SSO.

## Consequences

- The CI identity units must be applied once by an administrator, because CI
  cannot create the roles it logs in with. See README "First apply".
- Apply identities start with broad permissions (`AdministratorAccess`,
  `roles/owner`). This is a deliberate starting point, marked `ADOPT`, to narrow.
