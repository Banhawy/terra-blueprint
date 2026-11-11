include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_common/services/web-api.hcl"
}

# Production: redundancy on every tier. Bump image_tag to deploy.
inputs = {
  image_tag = "0.1.0"

  cpu          = 1024
  memory       = 2048
  min_capacity = 2
  max_capacity = 6

  db_instance_count = 2 # writer + failover reader
  db_min_capacity   = 1
  db_max_capacity   = 8
  cache_node_type   = "cache.t4g.small"
  cache_node_count  = 2 # primary + replica, automatic failover

  scheduled_tasks = {
    nightly-cleanup = {
      description         = "Example job: replace the command with your own"
      schedule_expression = "cron(0 3 * * ? *)"
      command             = ["echo", "nightly cleanup"]
    }
  }
}
