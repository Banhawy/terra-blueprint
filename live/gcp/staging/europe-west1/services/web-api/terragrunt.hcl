include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_common/services/web-api.hcl"
}

# Bump image_tag to deploy.
inputs = {
  image_tag     = "0.1.0"
  max_instances = 3
}
