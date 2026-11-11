include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_common/services/queue-worker.hcl"
}

inputs = {
  max_instances = 4
}
