# Infrastructure blueprint

A production-shaped Terraform + Terragrunt repository to copy as the starting
point for a company's infrastructure. It runs on AWS (staging and production)
and shows the same patterns on GCP (staging). Every name, account ID and domain
is a placeholder (`acme`, `111111111111`, `example.com`).

- **Two-tier modules.** Small *components* (VPC, ALB, ECS service, Aurora, ...)
  are combined into *services* (`web-api`, `static-site`, `queue-worker`).
- **DRY Terragrunt layout.** One `root.hcl` per cloud generates providers and
  backends, settings cascade down the directory tree, and environments differ
  only in data.
- **Secure by default.** Private buckets, encryption everywhere, IMDSv2, no SSH,
  no long-lived keys (CI uses OIDC), and secret values never in Terraform state.
- **Verified without cloud access.** Format, validate, lint, security scan,
  `terraform test` with mocked providers, and end-to-end validation of every unit.

## Contents

- [What gets deployed](#what-gets-deployed)
- [Repository layout](#repository-layout)
- [Tooling](#tooling)
- [Adopting this blueprint](#adopting-this-blueprint)
- [First apply](#first-apply)
- [Day to day](#day-to-day)
- [CI/CD](#cicd)
- [Checks](#checks)
- [Conventions](#conventions)

## What gets deployed

Per AWS environment (`live/aws/<env>/eu-central-1/`):

```
                         ┌──────────── network/vpc ────────────┐
                         │ public · private · database subnets │
                         │ NAT · S3 endpoint · (flow logs)     │
                         └─────────────────────────────────────┘
app.<domain> ─> CloudFront ─┬─> S3 (static-site)
                            └─ /api/* ─┐
api.<domain> ─> WAF ─> ALB ────────────┴─> ECS Fargate (web-api) ─┬─> Aurora PostgreSQL
                                                                  ├─> Valkey
                                                                  └─> S3 uploads
SQS ─> EC2 Auto Scaling 0..N (queue-worker) ─> S3 results
alarms + failed deploys ─> SNS ─> Lambda ─> chat webhook

operations/: acm (wildcard cert) · ecr (images) · github-oidc (CI roles)
```

Per GCP environment (`live/gcp/staging/europe-west1/`): VPC with Cloud NAT and
Private Services Access, Artifact Registry, Workload Identity Federation for CI,
and `web-api` (Cloud Run, private Cloud SQL with IAM auth, GCS, Secret Manager).

| | staging | production |
|---|---|---|
| NAT gateways | 1 (shared) | 1 per AZ |
| Interface endpoints, flow logs | off | on |
| ECS tasks | 1–2 | 2–6 |
| Aurora | 1 instance, ≤2 ACU | writer + reader, ≤8 ACU |
| Valkey | 1 node | primary + replica |
| Deletion protection | off | on |

The cost and availability settings live in each environment's `env.hcl`.

## Repository layout

```
common.hcl                    organisation-wide: project name, owner, GitHub repo, tags
mise.toml                     tool versions (the only place they are pinned)
live/                         what is deployed -- one directory per unit of state
  aws/
    root.hcl                  generates provider.tf (default_tags) + backend.tf (S3)
    _common/                  shared unit configs, included by every environment
    staging/
      env.hcl                 account_id, domain, CIDR, cost/availability knobs
      eu-central-1/
        region.hcl
        network/vpc/terragrunt.hcl
        operations/{acm,ecr,github-oidc}/terragrunt.hcl
        services/{web-api,static-site,queue-worker}/terragrunt.hcl
    production/ …             same shape
  gcp/
    root.hcl                  generates provider.tf (default_labels) + backend.tf (GCS)
    _common/
    staging/env.hcl           project_id, CIDR
    staging/europe-west1/…    network/vpc, operations/{project-services,artifact-registry,workload-identity}, services/web-api
modules/                      how things are built -- reusable, no environment knowledge
  aws/components/             one concern each: vpc, alb, ecs-service, aurora-postgresql, …
  aws/services/               web-api, static-site, queue-worker (compose components)
  gcp/components/             network, cloud-run-service, cloud-sql-postgres, …
  gcp/services/               web-api
scripts/                      validate, test, docs and hygiene scripts (used by CI and pre-commit)
docs/adr/                     why things are the way they are
```

A **unit** (any directory with a `terragrunt.hcl` under `live/`) is one
Terraform state. A unit's file is usually just two includes:

```hcl
include "root" {
  path = find_in_parent_folders("root.hcl")        # provider, backend, tags
}

include "common" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_common/services/web-api.hcl"
}

inputs = {                                          # only what differs here
  image_tag = "0.1.0"
}
```

Settings cascade: `common.hcl` → `env.hcl` → `region.hcl` → `_common/<unit>.hcl`
→ the unit's own `inputs`. Units read each other's outputs through `dependency`
blocks. Those carry `mock_outputs`, so `validate` and a first `plan` work before
the dependency exists; `apply` never uses mocks.

## Tooling

Every version is pinned in `mise.toml`: Terraform, Terragrunt, tflint, trivy,
terraform-docs, pre-commit, Python, AWS CLI and gcloud.

```sh
# Option 1: mise (https://mise.jdx.dev)
mise install
pre-commit install            # optional: run the checks on every commit

# Option 2: Docker (same versions, read from the same mise.toml)
docker compose build
docker compose run --rm terra
```

Terragrunt 1.x runs OpenTofu (`tofu`) by default. This repo sets
`TG_TF_PATH=terraform` (in `mise.toml`, the Dockerfile and CI). The code is
OpenTofu-compatible: set `TG_TF_PATH=tofu` to switch.

## Adopting this blueprint

Search for `ADOPT` to find every line you must decide on. In order:

1. **`common.hcl`**: `project` (the prefix of every resource name and state
   bucket), `owner`, `github_org`, `github_repo`.
2. **`live/aws/<env>/env.hcl`**: real `account_id`, `domain`, `route53_zone_id`
   (if your DNS is in Route 53), `vpc_cidr` (must not overlap your other networks).
3. **`live/gcp/<env>/env.hcl`**: real `project_id` (the project must already
   exist with billing enabled), `vpc_cidr`. Delete `live/gcp/` and `modules/gcp/`
   if you do not use GCP.
4. **Regions.** The region is the directory name (`eu-central-1`,
   `europe-west1`) plus `region.hcl`. Rename both together.
5. **`live/aws/_common/services/static-site.hcl`**: `frontend_repo`, the
   repository whose CI deploys the site.
6. **CI permissions.** The apply roles start as `AdministratorAccess` (AWS) and
   `roles/owner` (GCP) so the blueprint works out of the box. Narrow them once
   you know what you manage.
7. **GitHub.** Create Environments `staging` and `production`, and add required
   reviewers to `production`. Optionally set the repository variable
   `FORBIDDEN_TERMS` (see [Checks](#checks)).
8. **Services.** `web-api`, `static-site` and `queue-worker` are examples. Keep,
   rename, copy or delete them. A service is a module under `modules/*/services/`,
   a shared config under `live/*/_common/services/`, and one unit per environment.

## First apply

Run these from a workstation, as an administrator of each account or project.
After step 3, CI takes over.

**0. Authenticate.**
```sh
aws sso login --profile <staging-admin>  && export AWS_PROFILE=<staging-admin>
gcloud auth application-default login
```

**1. Create the state buckets.** One per AWS account and region, one per GCP
project. Terragrunt creates them versioned, encrypted and private.
```sh
cd live/aws/staging       && terragrunt backend bootstrap --all
cd live/gcp/staging       && terragrunt backend bootstrap --all
```

**2. Create the CI identities.** CI cannot create the roles it logs in with.
```sh
cd live/aws/staging/eu-central-1/operations/github-oidc && terragrunt apply
cd live/gcp/staging/europe-west1/operations/project-services && terragrunt apply
cd ../workload-identity && terragrunt apply
```

**3. Give CI those identities** as GitHub repository variables (Settings →
Secrets and variables → Actions → Variables). Read them with `terragrunt output`
in the units above.

| Variable | Value |
|---|---|
| `AWS_STAGING_PLAN_ROLE_ARN` | `role_arns["terraform-plan"]` (staging github-oidc) |
| `AWS_STAGING_APPLY_ROLE_ARN` | `role_arns["terraform-apply"]` (staging github-oidc) |
| `AWS_PRODUCTION_APPLY_ROLE_ARN` | `role_arns["terraform-apply"]` (production github-oidc) |
| `GCP_STAGING_WIF_PROVIDER` | `provider_name` (workload-identity) |
| `GCP_STAGING_PLAN_SERVICE_ACCOUNT` | `service_account_emails["tf-plan"]` |
| `GCP_STAGING_APPLY_SERVICE_ACCOUNT` | `service_account_emails["tf-apply"]` |

Until these are set, CI runs only the credential-free checks.

**4. Network, certificate and image registry.**
```sh
cd live/aws/staging/eu-central-1
terragrunt run --all --filter './network/**' --filter './operations/**' -- apply
```
Without a Route 53 zone, add the certificate's validation CNAMEs at your DNS
provider (`terragrunt output validation_records` in `operations/acm`). Wait until
ACM shows the certificate as ISSUED: load balancers refuse a pending certificate.

**5. Push the first image.** Push it to the ECR repository (`operations/ecr`
output) with the tag set in `services/web-api/terragrunt.hcl` (`image_tag`).
Tags are immutable.

**6. Services.**
```sh
cd live/aws/staging/eu-central-1/services && terragrunt run --all -- apply
```
Terragrunt applies them in dependency order (web-api, then static-site and
queue-worker). Then complete the one-time steps in each service's README:
secret values, the IAM database user, the alert webhook, DNS records.

**7. Production.** Repeat steps 0–6 in `live/aws/production`, or run step 1–3
by hand and let the `deploy` workflow do the rest.

## Day to day

```sh
# One unit
cd live/aws/staging/eu-central-1/services/web-api
terragrunt plan
terragrunt apply

# A whole environment, in dependency order
cd live/aws/staging
terragrunt run --all -- plan

# Only what changed versus main
terragrunt run --all --filter-affected -- plan
```

| Task | How |
|---|---|
| **Deploy a new app version** | Push the image, bump `image_tag` in the env's `services/web-api/terragrunt.hcl`, merge. Staging applies on merge; production through the `deploy` workflow. A failing deploy is rolled back by the ECS circuit breaker and reported to the alerts topic. |
| **Add a scheduled job** | Add an entry to `scheduled_tasks` in the web-api unit. |
| **Add an environment** | Copy `live/aws/staging` to `live/aws/<new>`, edit `env.hcl`, then do [first apply](#first-apply) steps 1–3. Unit files need no change. |
| **Add a region** | Copy `<env>/eu-central-1` to `<env>/<region>` and edit `region.hcl`. Each region gets its own state bucket. |
| **Add a service** | Write `modules/aws/services/<name>` from components, add `live/aws/_common/services/<name>.hcl`, and add a two-include unit per environment. |
| **Change a module** | Edit, then `scripts/test-modules.sh` and `scripts/validate-live.sh`. Every environment picks it up on its next apply. |

## CI/CD

`.github/workflows/`:

| Workflow | Trigger | Does |
|---|---|---|
| `ci` | every PR and push to `main` | All [checks](#checks). On PRs, once the plan variables exist: `plan` for AWS and GCP staging, written to the job summary. |
| `deploy` | push to `main` touching `live/`, `modules/` or `common.hcl` | `apply` AWS + GCP staging (GitHub Environment `staging`). |
| `deploy` | manual dispatch, `production` | `plan` then `apply` AWS production (GitHub Environment `production`: add required reviewers). |

There are no stored cloud credentials. Jobs exchange GitHub's OIDC token for
short-lived credentials. Each role trusts only this repository, and only the
context it is for: the `pull_request` event for plan roles, the matching GitHub
Environment for apply roles. Actions are referenced by major version; pin them
to commit SHAs if your policy requires it.

## Checks

All of these run in CI and none needs cloud credentials.

```sh
terraform fmt -recursive -check modules && terragrunt hcl fmt --check
scripts/validate-modules.sh       # terraform validate, every module
scripts/validate-live.sh          # every unit end to end: provider + module + inputs (no backend)
(cd live && terragrunt hcl validate --inputs --strict)   # inputs match module variables
(cd modules && tflint --recursive --config "$PWD/../.tflint.hcl")
trivy config --config trivy.yaml .                       # HIGH/CRITICAL misconfigurations
scripts/test-modules.sh           # terraform test with mocked providers
python -m pytest                  # worker stub and notifier Lambda
scripts/generate-docs.sh          # refresh module README tables (CI fails on drift)
scripts/check-forbidden-terms.sh  # see below
```

Accepted trivy findings are suppressed inline (`#trivy:ignore:<ID>`), next to
the resource and with the reason. They are never suppressed globally.

**Forbidden terms.** If this repository came from a previous organisation, set
the repository variable `FORBIDDEN_TERMS` to an extended regex of its
identifiers (names, account IDs, domains). CI then fails if any of them
reappears. The terms live only in the variable, never in the repository.

## Conventions

- **Never write `provider.tf` or `backend.tf`** in a unit. `root.hcl` generates
  them, and they are git-ignored.
- **Tags and labels come from the provider** (`default_tags` / `default_labels`),
  not from module variables. Every AWS resource also carries `Unit`, the path
  of the unit that owns it.
- **Names** are `<project>-<environment>-<thing>`, e.g. `acme-staging-web-api`.
- **Secrets.** Terraform creates secret containers, and values are set out of
  band. Database passwords are generated by RDS or replaced by IAM
  authentication, so no secret value ever enters state.
- **Modules know nothing about environments.** They take explicit inputs.
  Environment knowledge lives in `live/`.
- **Components never call services**, and services never call other services:
  they exchange values through unit `dependency` blocks.
- **Lock files.** Commit `.terraform.lock.hcl` in units (`live/`). Modules don't
  have lock files.
- **Decisions** are recorded in [`docs/adr/`](docs/adr/).
