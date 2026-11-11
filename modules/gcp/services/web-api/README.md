# web-api (GCP)

The GCP counterpart of the AWS web-api, on managed equivalents.

```
internet ─> Cloud Run (*.run.app) ──Direct VPC egress──> Cloud SQL PostgreSQL (private IP, IAM auth)
                 ├─> Secret Manager (app secrets)
                 └─> GCS uploads bucket
Cloud Monitoring alert policies: 5xx rate, database CPU
```

| AWS | GCP |
|---|---|
| ECS Fargate + ALB | Cloud Run |
| Aurora PostgreSQL | Cloud SQL for PostgreSQL |
| S3 | Cloud Storage |
| Secrets Manager | Secret Manager |
| CloudWatch alarms + SNS | Cloud Monitoring alert policies + notification channels |

- **Identity.** The service runs as its own service account with exactly
  `cloudsql.client`, `cloudsql.instanceUser`, object access to the uploads
  bucket and accessor on its own secrets.
- **Database.** Private IP only, TLS required, IAM database authentication: the
  app connects as `DATABASE_USER` (its service account) with a token from the
  Cloud SQL Python/Go/Java connector, never a password.
- **Not included (yet):** a global HTTPS load balancer with a serverless NEG
  and Cloud Armor. Add it for a custom domain and WAF, then set the service's
  ingress to `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`.

After the first apply, add secret values
(`gcloud secrets versions add <id> --data-file=-`) for each entry in
`app_secret_ids`, and grant the IAM database user its privileges once:
`GRANT ALL ON DATABASE app TO "<DATABASE_USER>";`.

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.10 |
| google | ~> 8.11 |

### Providers

| Name | Version |
| ---- | ------- |
| google | ~> 8.11 |

### Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| database | ../../components/cloud-sql-postgres | n/a |
| secrets | ../../components/secret-manager | n/a |
| service | ../../components/cloud-run-service | n/a |
| uploads | ../../components/gcs-bucket | n/a |

### Resources

| Name | Type |
| ---- | ---- |
| [google_monitoring_alert_policy.database_cpu](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_alert_policy) | resource |
| [google_monitoring_alert_policy.server_errors](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_alert_policy) | resource |
| [google_project_iam_member.runtime](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_service_account.runtime](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_storage_bucket_iam_member.uploads](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [google_client_config.current](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config) | data source |
| [google_project.current](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| image\_repository | Image path without tag, e.g. europe-west1-docker.pkg.dev/acme-staging/acme-staging/web-api. | `string` | n/a | yes |
| image\_tag | Image tag to deploy. Bumping it is a deploy. | `string` | n/a | yes |
| name | Service name and prefix for its resources, e.g. acme-staging-web-api. | `string` | n/a | yes |
| network\_id | VPC network with Private Services Access (network unit). | `string` | n/a | yes |
| region | Region for Cloud Run, Cloud SQL and the bucket. | `string` | n/a | yes |
| subnet\_id | Subnet for Cloud Run Direct VPC egress (network unit). | `string` | n/a | yes |
| alarm\_5xx\_per\_minute | 5xx responses per minute (sustained 5 minutes) that open an incident. | `number` | `1` | no |
| allow\_unauthenticated | Public API: anyone may invoke it (the app does its own auth). | `bool` | `true` | no |
| app\_secrets | Secrets for the app (values set by hand). Key "app-secret-key" is exposed as APP\_SECRET\_KEY. | ```map(object({ description = string }))``` | ```{ "app-secret-key": { "description": "Application signing key" } }``` | no |
| container\_port | Port the application listens on. | `number` | `8080` | no |
| db\_high\_availability | Regional (HA) Cloud SQL instance. | `bool` | `false` | no |
| db\_name | Application database name. | `string` | `"app"` | no |
| db\_tier | Cloud SQL machine tier. | `string` | `"db-custom-1-3840"` | no |
| deletion\_protection | Protect the service and database from deletion; refuse to destroy a non-empty bucket. | `bool` | `false` | no |
| extra\_environment | Additional plain environment variables. | `map(string)` | `{}` | no |
| health\_check\_path | Startup/liveness probe path. | `string` | `"/healthz"` | no |
| max\_instances | Maximum instances. | `number` | `3` | no |
| min\_instances | Warm instances (0 = scale to zero). | `number` | `0` | no |
| notification\_channels | Cloud Monitoring notification channel IDs for alert policies (e-mail, Slack, PagerDuty). | `list(string)` | `[]` | no |
| uploads\_cors\_origins | Browser origins allowed to upload with signed URLs. | `list(string)` | `[]` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| app\_secret\_ids | Secrets that need a value before the service can start (gcloud secrets versions add <id> --data-file=-). |
| database\_connection\_name | Cloud SQL connection name (for the Cloud SQL Auth Proxy / connectors). |
| database\_private\_ip | Cloud SQL private IP. |
| service\_account\_email | Runtime identity; grant it access to anything else the app needs. |
| uploads\_bucket | Uploads bucket. |
| url | Service URL. |
<!-- END_TF_DOCS -->
