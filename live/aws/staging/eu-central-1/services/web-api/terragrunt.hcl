include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_common/services/web-api.hcl"
}

# Staging: smallest footprint. Bump image_tag to deploy.
inputs = {
  image_tag = "0.1.0"

  min_capacity    = 1
  max_capacity    = 2
  db_max_capacity = 2

  scheduled_tasks = {
    nightly-cleanup = {
      description         = "Example job: replace the command with your own"
      schedule_expression = "cron(0 3 * * ? *)"
      command             = ["echo", "nightly cleanup"]
    }
  }
}
