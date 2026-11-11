# CLAUDE.md

Guidance for AI coding agents working in this repository. Humans: start with README.md.

## What this is

Terraform + Terragrunt infrastructure for AWS (staging, production) and GCP
(staging). `modules/` holds reusable code, `live/` holds what is deployed: each
directory with a `terragrunt.hcl` is one unit of state.

## Commands

Tools come from `mise.toml` (`mise install`, or `docker compose run --rm terra`).
Terragrunt must run Terraform: `TG_TF_PATH=terraform` (set by mise).

```sh
cd live/aws/staging/eu-central-1/services/web-api && terragrunt plan   # one unit
cd live/aws/staging && terragrunt run --all -- plan                    # a stack

scripts/validate-modules.sh     # terraform validate every module
scripts/validate-live.sh        # validate every unit end to end, no cloud access
scripts/test-modules.sh         # terraform test (mocked providers)
python -m pytest                # Python shipped with modules
(cd modules && tflint --recursive --config "$PWD/../.tflint.hcl")
trivy config --config trivy.yaml .
scripts/generate-docs.sh        # after changing a service's variables/outputs
```

Run the checks relevant to your change before you finish. All of them work
without credentials. Never run `apply` unless the user asks.

## Rules

- Never create `provider.tf` or `backend.tf` in a unit. `live/<cloud>/root.hcl` generates them.
- No `tags`/`labels` variables in modules: provider `default_tags` / `default_labels` apply them (ADR 0003).
- Components (`modules/*/components`) do one thing and never call services.
  Services compose components and never call other services (ADR 0001).
- Modules know nothing about environments. Environment differences go in
  `env.hcl` or a unit's `inputs`. Shared unit config goes in `live/<cloud>/_common/`.
- `count`/`for_each` must depend only on values known at plan time: map keys,
  list lengths, input booleans. Never on computed JSON or ARNs (for example, use
  `policies = map(name => json)`, not `policy_json != null`).
- New `dependency` blocks need `mock_outputs` with
  `mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]`.
- Secret values never go in code or state. Create the secret container and
  document how its value is set.
- Accepting a trivy finding means an inline `#trivy:ignore:<ID> -- <reason>` on
  the resource. Verify the ID actually matches a finding.
- Every variable and output has a `description`. Every behaviour a module
  exists to guarantee has a `terraform test` assertion.
- Placeholders (`acme`, `111111111111`, `example.com`) are intentional. Do not
  replace them with real values unless asked.
