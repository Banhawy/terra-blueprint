include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Everything this unit needs is shared across environments; see the file below.
# Add an `inputs = { ... }` block here to override a value for staging only.
include "common" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_common/operations/acm.hcl"
}
