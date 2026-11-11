# 0003. Tags and labels come from the provider, not from module variables

- Status: accepted

## Context

Passing a `tags` map into every module and remembering to put it on every
resource is repetitive and fails silently: one forgotten `tags = var.tags`
gives an untagged resource that no cost report or audit query finds.

## Decision

- AWS: `root.hcl` sets `default_tags` on the provider: `Project`, `Owner`,
  `Environment`, `ManagedBy`, and `Unit` (the path of the owning unit).
- GCP: `root.hcl` sets `default_labels`, normalised to lowercase as GCP requires.
- Modules take no tags variable. They set only resource-specific tags such as `Name`.
- Exception: instances launched by an Auto Scaling group do not inherit provider
  default tags. The `asg` component reads them with `data "aws_default_tags"`
  and copies them onto the launch template's tag specifications.

## Consequences

- Nothing Terraform creates can be untagged, and `Unit` leads from any resource
  in the console straight to the code that owns it.
- Resources created *by AWS on your behalf* (e.g. ENIs) still follow AWS's own
  tagging rules.
