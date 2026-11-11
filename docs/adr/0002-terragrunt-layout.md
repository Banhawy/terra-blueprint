# 0002. One root.hcl per cloud; settings cascade down the directory tree

- Status: accepted

## Context

Each unit of state needs a provider configuration and a backend. Writing those
by hand per unit leads to drift: a missing tag here, a wrong state key there.
A single root for every cloud would need a conditional backend type and
provider, which is hard to read and easy to break.

## Decision

- `live/<cloud>/root.hcl` generates `provider.tf` and `backend.tf` for every unit
  of that cloud. Units include it with `find_in_parent_folders("root.hcl")`, so
  the nearest root wins.
- Settings live at the level they vary at: `common.hcl` (organisation), then
  `env.hcl` (account/project, domain, cost knobs), then `region.hcl`.
- Unit configuration shared by all environments lives in
  `live/<cloud>/_common/<unit>.hcl`. Each environment's unit file includes it and
  overrides only what differs (image tag, sizing).
- State: S3 with native lock files on AWS (no DynamoDB table); GCS on GCP. One
  bucket per account and region (AWS) or per project (GCP), created by
  `terragrunt backend bootstrap`.
- Module sources use `get_repo_root()` with `//`, so the whole `modules/` tree is
  copied and relative component paths keep working.

## Consequences

- Adding an environment is copying a directory and editing `env.hcl`. Unit
  files do not change.
- Reading a unit means following two includes. The README's layout section
  explains the chain.
- `dependency` blocks carry `mock_outputs` limited to `init`, `validate` and
  `plan`, so new environments can be validated and planned before anything
  exists. `apply` always uses real outputs.
