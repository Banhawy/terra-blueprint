# Enables the Google APIs the rest of the stack needs. Applied first in every
# project: almost every other resource fails until its API is on.
resource "google_project_service" "this" {
  for_each = var.services

  service = each.value

  # Turning an API off on destroy can break things outside this repo.
  disable_on_destroy         = false
  disable_dependent_services = false
}
