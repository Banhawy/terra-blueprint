# queue-worker (AWS)

Background jobs pulled from a queue by EC2 instances that exist only while
there is work.

```
producer ─> SQS queue ──(after max_receive_count failures)──> dead-letter queue
               │
               └─> Auto Scaling group 0..max_instances
                     worker.py: receive → process → write S3 result → delete
```

- **Scale to zero.** A queue-depth alarm adds an instance when messages wait;
  another removes one after 15 empty minutes.
- **No job is killed mid-flight.** While processing, the worker sets
  *scale-in protection* on its own instance (`autoscaling:SetInstanceProtection`)
  and clears it afterwards. Instance refresh waits for protected instances.
- **At-least-once.** A message is deleted only after its result is stored. Make
  `process()` idempotent: a job can run again after a crash or timeout.
  `job_timeout_seconds` must exceed your longest job (it is the visibility timeout).
- **Code ships from S3.** Everything under `worker/` is uploaded under a key
  containing its hash. Changing the code changes the launch template's user
  data, which rolls the instances. Bootstrap: `user_data.sh.tftpl`.
- **Access** is via SSM Session Manager (`aws ssm start-session --target <id>`);
  there is no SSH. Logs: CloudWatch group `/ec2/<name>`.

Replace `process()` in `worker/worker.py` with the real work and add its
dependencies to `worker/requirements.txt`. Tests: `tests/test_worker.py`.

**Producing jobs:** attach the `producer_policy_json` output to whatever enqueues
(e.g. the web-api task role) and send JSON bodies to `queue_url`.
**Dead letters:** inspect, fix, then
`aws sqs start-message-move-task --source-arn <dlq-arn>`.

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.10 |
| aws | ~> 6.72 |

### Providers

| Name | Version |
| ---- | ------- |
| aws | ~> 6.72 |

### Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| alarms | ../../components/cloudwatch/alarms | n/a |
| code | ../../components/s3 | n/a |
| logs | ../../components/cloudwatch/log-group | n/a |
| results | ../../components/s3 | n/a |
| scaling\_alarms | ../../components/cloudwatch/alarms | n/a |
| workers | ../../components/asg | n/a |

### Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_role_policy.worker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_s3_object.code](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_sqs_queue.dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.jobs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue_redrive_allow_policy.dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_redrive_allow_policy) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.producer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.worker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Worker name and prefix for its resources, e.g. acme-staging-queue-worker. | `string` | n/a | yes |
| private\_subnet\_ids | Private subnets for the worker instances (they need NAT or VPC endpoints to reach AWS APIs). | `list(string)` | n/a | yes |
| vpc\_id | VPC for the worker instances. | `string` | n/a | yes |
| alarm\_oldest\_message\_age\_seconds | Alarm when the oldest waiting job is older than this. | `number` | `1800` | no |
| alarm\_topic\_arn | SNS topic for operational alarms (DLQ, backlog age, CPU) -- e.g. web-api's alerts topic. Null = alarms without notifications. | `string` | `null` | no |
| force\_destroy | Allow destroying the results bucket while it holds results. | `bool` | `false` | no |
| instance\_type | Worker instance type. | `string` | `"t3.small"` | no |
| job\_timeout\_seconds | Longest a single job may take. Becomes the queue's visibility timeout and the worker's graceful-stop timeout. | `number` | `900` | no |
| log\_retention\_in\_days | Worker log retention. | `number` | `30` | no |
| max\_instances | Upper bound on concurrent workers (one job per worker at a time). | `number` | `2` | no |
| max\_receive\_count | Attempts before a message is moved to the dead-letter queue. | `number` | `3` | no |
| message\_retention\_seconds | How long unprocessed jobs stay in the queue. | `number` | `345600` | no |
| results\_retention\_days | Days results are kept in the results bucket. | `number` | `30` | no |
| scale\_out\_backlog | Visible messages that trigger adding a worker. | `number` | `1` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| asg\_name | Auto Scaling group running the workers. |
| dlq\_url | Dead-letter queue. Redrive with `aws sqs start-message-move-task --source-arn <dlq arn>`. |
| producer\_policy\_json | IAM policy granting enqueue + result read. Attach it to whatever produces jobs. |
| queue\_arn | Job queue ARN. |
| queue\_url | Send jobs here (JSON message bodies). |
| results\_bucket | Bucket the worker writes results/<message id>.json to. |
<!-- END_TF_DOCS -->
