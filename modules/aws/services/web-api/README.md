# web-api (AWS)

A containerised HTTP API with its database, cache, file storage, alerting and
scheduled jobs.

```
internet ─> WAF ─> ALB (TLS, host rule) ─> ECS Fargate tasks ─┬─> Aurora PostgreSQL Serverless v2
                                                              ├─> ElastiCache Valkey (TLS)
                                                              └─> S3 uploads bucket
CloudWatch alarms + failed-deploy events ─> SNS ─> notifier Lambda ─> chat webhook
EventBridge Scheduler ─> one-off Fargate tasks (scheduled_tasks)
```

| File | Contents |
|---|---|
| `main.tf` | ALB, target group and host rule, WAF, ECS service, Aurora, Valkey, uploads bucket, app secrets |
| `permissions.tf` | Task-role policy: uploads bucket, `rds-db:connect` |
| `alerting.tf` | SNS topic, core alarms, failed-deployment rule, webhook notifier |
| `scheduled-tasks.tf` | EventBridge Scheduler schedules running the task with a command override |
| `dns.tf` | Optional Route 53 alias record |
| `notifier/` | Lambda source (Python, stdlib + boto3); tests in `tests/test_notifier.py` |

## The application contract

The container receives:

| Variable | Value |
|---|---|
| `PORT` | `container_port` |
| `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_NAME` | Aurora writer endpoint |
| `DATABASE_IAM_AUTH` | `true` → connect as `DATABASE_USER` with an IAM token (`rds.generate_db_auth_token`), no password |
| `DATABASE_USER` / `DATABASE_PASSWORD` | only when `db_use_iam_auth = false`: the RDS-managed master credentials |
| `CACHE_URL` | `valkeys://<host>:6379/0` (TLS) |
| `UPLOADS_BUCKET` | uploads bucket name |
| `APP_SECRET_KEY` | from Secrets Manager (one variable per entry in `app_secrets`) |

It must answer `GET /healthz` with 200 without authentication.

## After the first apply

1. **Secret values.** Put values in the secrets listed in the `app_secret_arns`
   output (`aws secretsmanager put-secret-value --secret-id <arn> --secret-string ...`);
   tasks fail to start until they exist.
2. **IAM database user** (when `db_use_iam_auth = true`). Connect once as the master
   user (credentials in `database_master_secret_arn`) and run:
   ```sql
   CREATE USER app;
   GRANT rds_iam TO app;
   GRANT ALL ON DATABASE app TO app;
   ```
3. **Alerts.** Put an incoming-webhook URL in `alert_webhook_secret_arn`.
4. **DNS.** Without a Route 53 zone, create the record in the `dns_records` output.

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.10 |
| archive | ~> 2.8 |
| aws | ~> 6.72 |

### Providers

| Name | Version |
| ---- | ------- |
| aws | ~> 6.72 |

### Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| alarms | ../../components/cloudwatch/alarms | n/a |
| alb | ../../components/alb | n/a |
| app | ../../components/ecs-service | n/a |
| cache | ../../components/elasticache | n/a |
| database | ../../components/aurora-postgresql | n/a |
| notifier | ../../components/lambda | n/a |
| notifier\_secret | ../../components/secretmanager | n/a |
| secrets | ../../components/secretmanager | n/a |
| uploads | ../../components/s3 | n/a |
| waf | ../../components/waf | n/a |

### Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_event_rule.deployment_failed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.deployment_failed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_iam_role.scheduler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.scheduler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_lambda_permission.notifier_sns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lb_listener_rule.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_route53_record.api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_scheduler_schedule.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/scheduler_schedule) | resource |
| [aws_sns_topic.alerts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.alerts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [aws_sns_topic_subscription.notifier](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.alerts_topic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.notifier](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.scheduler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.scheduler_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| certificate\_arn | ACM certificate covering hostname. | `string` | n/a | yes |
| database\_subnet\_ids | Isolated subnets for the database and cache. | `list(string)` | n/a | yes |
| hostname | Public hostname of the API, e.g. api.staging.example.com. Requests for other hosts get a 404. | `string` | n/a | yes |
| image\_repository | Image repository URL (from the ecr unit). | `string` | n/a | yes |
| image\_tag | Image tag to deploy. Bumping it is a deploy. | `string` | n/a | yes |
| name | Service name and prefix for all its resources, e.g. acme-staging-web-api (max 32 characters: ALB limit). | `string` | n/a | yes |
| private\_subnet\_ids | Subnets for the tasks. | `list(string)` | n/a | yes |
| public\_subnet\_ids | Subnets for the load balancer. | `list(string)` | n/a | yes |
| vpc\_cidr | VPC CIDR (limits the ALB's egress). | `string` | n/a | yes |
| vpc\_id | VPC to deploy into. | `string` | n/a | yes |
| alarm\_5xx\_threshold | 5xx responses per 5 minutes that raise an alarm. | `number` | `10` | no |
| alarm\_cpu\_threshold | Service CPU % that raises an alarm. | `number` | `85` | no |
| alarm\_memory\_threshold | Service memory % that raises an alarm. | `number` | `85` | no |
| alert\_notifier\_enabled | Deploy the Lambda that forwards alerts to a chat webhook. | `bool` | `true` | no |
| app\_secrets | Secrets created for the app (values set by hand). Key "app-secret-key" is exposed as env var APP\_SECRET\_KEY. | ```map(object({ description = string }))``` | ```{ "app-secret-key": { "description": "Application signing key" } }``` | no |
| cache\_node\_count | Valkey nodes (2+ adds a replica with automatic failover). | `number` | `1` | no |
| cache\_node\_type | Valkey node type. | `string` | `"cache.t4g.micro"` | no |
| container\_port | Port the application listens on (exported to it as PORT). | `number` | `8000` | no |
| cpu | Task CPU units. | `number` | `512` | no |
| db\_app\_username | Database user the application connects as when db\_use\_iam\_auth is true. | `string` | `"app"` | no |
| db\_instance\_count | Aurora instances (2+ adds a failover reader). | `number` | `1` | no |
| db\_max\_capacity | Maximum Aurora capacity units. | `number` | `4` | no |
| db\_min\_capacity | Minimum Aurora capacity units. | `number` | `0.5` | no |
| db\_name | Name of the application database. | `string` | `"app"` | no |
| db\_use\_iam\_auth | Connect with IAM database authentication (no password). Requires a one-time SQL step as the master user: CREATE USER <db\_app\_username>; GRANT rds\_iam TO <db\_app\_username>; false = the app uses the RDS-managed master credentials from Secrets Manager. | `bool` | `true` | no |
| deletion\_protection | Protect the ALB and database from deletion, keep a final DB snapshot, and refuse to destroy a non-empty bucket. | `bool` | `false` | no |
| extra\_environment | Additional plain environment variables for the application. | `map(string)` | `{}` | no |
| extra\_secret\_arns | ARNs of the secrets referenced in extra\_secrets, so the execution role can read them. | `list(string)` | `[]` | no |
| extra\_secrets | Additional env var -> Secrets Manager ARN mappings for secrets created elsewhere. | `map(string)` | `{}` | no |
| health\_check\_grace\_period\_seconds | Seconds after task start before failed health checks count. Cover migrations and warm-up. | `number` | `120` | no |
| health\_check\_path | Path the load balancer polls; must return 200 without auth. | `string` | `"/healthz"` | no |
| max\_capacity | Maximum running tasks under load. | `number` | `2` | no |
| memory | Task memory (MiB). | `number` | `1024` | no |
| min\_capacity | Minimum running tasks. | `number` | `1` | no |
| route53\_zone\_id | Hosted zone to create the hostname record in. Null = add the record from the dns\_records output by hand. | `string` | `null` | no |
| scheduled\_tasks | Jobs that run the service image on a schedule with a different command, e.g.   cleanup = {     description         = "Purge expired sessions"     schedule\_expression = "cron(0 3 * * ? *)"     command             = ["python", "manage.py", "clearsessions"]   } | ```map(object({ description = string schedule_expression = string command = list(string) timezone = optional(string, "UTC") enabled = optional(bool, true) }))``` | `{}` | no |
| uploads\_cors\_origins | Browser origins allowed to upload straight to the bucket with presigned URLs, e.g. ["https://app.example.com"]. | `list(string)` | `[]` | no |
| waf\_enabled | Attach a WAF web ACL to the load balancer. | `bool` | `true` | no |
| waf\_managed\_rule\_groups | AWS managed rule groups. CommonRuleSet starts in count mode: watch its metrics before letting it block. | ```list(object({ name = string vendor_name = optional(string, "AWS") priority = number count_only = optional(bool, false) excluded_rules = optional(list(string), []) }))``` | ```[ { "name": "AWSManagedRulesAmazonIpReputationList", "priority": 10 }, { "name": "AWSManagedRulesKnownBadInputsRuleSet", "priority": 20 }, { "count_only": true, "name": "AWSManagedRulesCommonRuleSet", "priority": 30 } ]``` | no |
| waf\_rate\_limit\_per\_5min | Requests per 5 minutes from one IP before it is blocked. | `number` | `2000` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| alb\_dns\_name | Load balancer DNS name; also the origin for a CloudFront /api/* proxy. |
| alert\_webhook\_secret\_arn | Secret to put the chat webhook URL in. |
| alerts\_topic\_arn | SNS topic receiving all alarms; subscribe more targets here. |
| app\_secret\_arns | Secrets whose values must be set before the app can start. |
| cache\_endpoint | Valkey primary endpoint (TLS). |
| cluster\_name | ECS cluster. |
| database\_endpoint | Aurora writer endpoint. |
| database\_master\_secret\_arn | RDS-managed master credentials (for admin tasks like creating the IAM-auth user). |
| dns\_records | Records to create at your DNS provider (empty when Route 53 manages them). |
| hostname | Public hostname of the API (e.g. the origin for a CloudFront /api/* proxy). |
| service\_name | ECS service (for `aws ecs execute-command` and deploy scripts). |
| task\_role\_arn | Role the application runs as. |
| uploads\_bucket | Uploads bucket. |
| url | Public URL of the API. |
<!-- END_TF_DOCS -->
