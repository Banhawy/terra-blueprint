# Enables the project's APIs. Every other GCP unit depends on this one.
terraform {
  source = "${get_repo_root()}/modules//gcp/components/project-services"
}
