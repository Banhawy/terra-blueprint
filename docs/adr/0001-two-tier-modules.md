# 0001. Modules come in two tiers: components and services

- Status: accepted

## Context

A flat folder of modules tends to go one of two ways. Either every module is a
thin wrapper around one resource, and each environment re-assembles the same
twenty resources by hand. Or every application gets a bespoke module that
re-implements its load balancer, database and buckets in slightly different ways.

## Decision

- **Components** (`modules/<cloud>/components/`) own one concern each: a VPC, a
  load balancer, an ECS service, a database. They encode the secure defaults
  once: encryption, private networking, least-privilege roles, IMDSv2.
- **Services** (`modules/<cloud>/services/`) are application-shaped. They compose
  components and add only the glue that is specific to that kind of
  application: listener rules, IAM policies between the parts, alarms.
- Components never call services. Services never call other services. Values
  cross service boundaries through Terragrunt `dependency` blocks in `live/`.
- Neither tier knows about environments. Everything that differs between
  staging and production is an input.

## Consequences

- A security fix in a component (e.g. TLS policy) reaches every service on its
  next apply.
- A new service is mostly composition, so it is quick to write and review.
- Some duplication remains between services by design: two services that
  happen to look alike today are free to diverge tomorrow.
- Each component has a `tests/` suite where the guarantees it exists for are
  asserted with `terraform test` (mocked providers), e.g. "buckets are never
  public", "instances require IMDSv2".
