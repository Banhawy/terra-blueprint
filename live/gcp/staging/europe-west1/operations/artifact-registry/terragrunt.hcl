include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_common/operations/artifact-registry.hcl"
}
