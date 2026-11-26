## ADDED Requirements

### Requirement: Three optional access settings, absent means today

The AWS Terraform (`terraform/aws/variables.tf`, read by both the network folder `terraform/aws/vpc` and the cluster folder `terraform/aws/eks` through the shared `env.tfvars`) SHALL declare three top-level variables, each `list(string)` with `default = null`:

- `app_irsa_s3_buckets`: the S3 bucket names the application role may use.
- `app_irsa_sqs_queues`: the SQS queue names the application role may use.
- `cluster_endpoint_public_access_cidrs`: the address ranges allowed to reach the cluster's public API endpoint.

A setting that is not present in `env.tfvars` (or is set to `null`) SHALL leave that part of the install exactly as it is today. Not present and an empty list SHALL be different states. Validated by the mock-provider runs in `terraform/aws/eks/tests/node_diagnostics.tftest.hcl` and by saved real `terraform plan` evidence.

#### Scenario: Settings absent keep today's policy and endpoint (accept and keep)

- **GIVEN** all three settings are `null`
- **WHEN** `terraform test` plans the cluster folder
- **THEN** the role's statements are exactly `FullS3` (`s3:*` on `*`) followed by `FullSqs` (`sqs:*` on `*`)
- **AND** the policy and its attachment are each planned once
- **AND** the value passed to the EKS module's `cluster_endpoint_public_access_cidrs` input is `["0.0.0.0/0"]`

#### Scenario: Existing install's unchanged env.tfvars plans no access change (backward compatibility)

- **GIVEN** an `env.tfvars` shaped like the one today's `setup-eks` writes, with none of the three settings
- **WHEN** `terraform plan` runs in `terraform/aws/eks` with the code before this change and again with this change
- **THEN** the rendered `aws_iam_policy.s3_sqs_admin` policy JSON is byte-for-byte identical in both plans
- **AND** the EKS cluster's `vpc_config` endpoint values (`endpoint_private_access`, `endpoint_public_access`, `public_access_cidrs`) are identical in both plans

#### Scenario: Current Harness guidance keeps working during rollout (backward compatibility)

- **GIVEN** an operator follows the Harness Terraform guide as published before this change, which sets none of the three settings
- **WHEN** they run `bin/environment eks`
- **THEN** the role keeps `s3:*` and `sqs:*` on `*` and the endpoint stays open to `0.0.0.0/0`, as before this change

#### Scenario: Network folder accepts the new settings without warnings

- **GIVEN** the `env.tfvars` that `setup-eks` writes in its first rewrite, carrying all three settings
- **WHEN** `terraform plan` runs in `terraform/aws/vpc`
- **THEN** the output contains no `Warning` and no `Error` line

### Requirement: Named buckets get only bucket-level and object-level access

When `app_irsa_s3_buckets` lists names, the application role's policy SHALL contain, in place of `FullS3`:

- a statement with Sid `S3Buckets` allowing `s3:ListBucket` and `s3:GetBucketLocation` on `arn:<partition>:s3:::<bucket>` for each named bucket;
- a statement with Sid `S3Objects` allowing `s3:GetObject`, `s3:GetObjectTagging`, `s3:PutObject`, `s3:DeleteObject`, `s3:PutObjectTagging` and `s3:AbortMultipartUpload` on `arn:<partition>:s3:::<bucket>/*` for each named bucket.

No S3 statement SHALL name the resource `*`.

#### Scenario: Named buckets are scoped (accept and scope)

- **GIVEN** `app_irsa_s3_buckets = ["groundx-files", "extract-bucket"]`
- **WHEN** Terraform plans the cluster folder
- **THEN** the S3 statements are `S3Buckets` on `arn:aws:s3:::groundx-files` and `arn:aws:s3:::extract-bucket`, and `S3Objects` on `arn:aws:s3:::groundx-files/*` and `arn:aws:s3:::extract-bucket/*`
- **AND** no statement has the resource `*` and no statement has Sid `FullS3`

The variable's validation SHALL reject any entry that uses a character other than letters, digits, `.`, `_` and `-` (each entry must match `^[A-Za-z0-9._-]+$`), and SHALL be written as a conditional expression (`null ? true : ...`) so `null` passes on Terraform 1.9.8. An empty list passes.

Invariant: a bucket entry reaches the policy only when it uses those characters alone; an absent setting or an empty list is never rejected.

#### Scenario: Wildcard bucket entry is rejected (catches)

- **GIVEN** `app_irsa_s3_buckets = ["groundx-files", "*"]`
- **WHEN** Terraform plans the cluster folder
- **THEN** the plan fails on this variable's validation and no resource is planned

#### Scenario: Absent, empty and plain bucket names are not rejected (must not block)

- **GIVEN** `app_irsa_s3_buckets` is `null`, or `[]`, or `["groundx-files"]`
- **WHEN** Terraform plans the cluster folder
- **THEN** this variable's validation passes

### Requirement: Named queues get only the queue operations GroundX uses

When `app_irsa_sqs_queues` lists names, the policy SHALL contain, in place of `FullSqs`, a statement with Sid `SqsQueues` allowing `sqs:SendMessage`, `sqs:ReceiveMessage`, `sqs:DeleteMessage`, `sqs:ChangeMessageVisibility`, `sqs:GetQueueAttributes` and `sqs:GetQueueUrl` on `arn:<partition>:sqs:<environment.region>:<account id>:<queue>` for each named queue, where the partition and account id come from the AWS credentials Terraform runs with.

#### Scenario: Named queues are scoped by full queue ARN (accept and scope)

- **GIVEN** `app_irsa_sqs_queues = ["file-process"]`, `environment.region = "us-west-2"` and an account id of `123456789012`
- **WHEN** Terraform plans the cluster folder
- **THEN** the SQS statement is `SqsQueues` on `arn:aws:sqs:us-west-2:123456789012:file-process` only
- **AND** no statement has Sid `FullSqs` and no SQS statement has the resource `*`

The variable's validation SHALL reject any entry that uses a character other than letters, digits, `.`, `_` and `-` (each entry must match `^[A-Za-z0-9._-]+$`), and SHALL be written as a conditional expression (`null ? true : ...`) so `null` passes on Terraform 1.9.8. An empty list passes.

Invariant: a queue entry reaches the policy only when it uses those characters alone; an absent setting or an empty list is never rejected.

#### Scenario: Wildcard queue entry is rejected (catches)

- **GIVEN** `app_irsa_sqs_queues = ["file-process", "*"]`
- **WHEN** Terraform plans the cluster folder
- **THEN** the plan fails on this variable's validation and no resource is planned

#### Scenario: Absent, empty and plain queue names are not rejected (must not block)

- **GIVEN** `app_irsa_sqs_queues` is `null`, or `[]`, or `["file-process", "jobs.fifo"]`
- **WHEN** Terraform plans the cluster folder
- **THEN** this variable's validation passes

### Requirement: An empty list grants no access for that service, independently

An empty list SHALL produce no statement for that service. S3 and SQS SHALL be decided independently: each setting's state affects only its own statements.

#### Scenario: Empty S3 list with named queues (reject the service, keep the other)

- **GIVEN** `app_irsa_s3_buckets = []` and `app_irsa_sqs_queues = ["file-process"]`
- **WHEN** Terraform plans the cluster folder
- **THEN** the policy has the `SqsQueues` statement only
- **AND** no statement is `FullS3`, `S3Buckets` or `S3Objects`

#### Scenario: Empty SQS list with named buckets (reject the service, keep the other)

- **GIVEN** `app_irsa_s3_buckets = ["groundx-files"]` and `app_irsa_sqs_queues = []`
- **WHEN** Terraform plans the cluster folder
- **THEN** the policy has the `S3Buckets` and `S3Objects` statements only
- **AND** no statement is `FullSqs` or `SqsQueues`

#### Scenario: Empty S3 list leaves absent SQS at today's access

- **GIVEN** `app_irsa_s3_buckets = []` and `app_irsa_sqs_queues` absent
- **WHEN** Terraform plans the cluster folder
- **THEN** the policy has the `FullSqs` statement only

### Requirement: Both lists empty attach no S3/SQS policy and keep the role

When both `app_irsa_s3_buckets` and `app_irsa_sqs_queues` are empty lists, Terraform SHALL plan neither the S3/SQS policy nor its attachment, and SHALL keep the role `eyelevel-s3-sqs-worker-irsa`. The policy and attachment SHALL carry `count`, with explicit `moved` blocks from their previous unindexed addresses to index `0`, so an existing install's policy is moved, not replaced.

#### Scenario: Both lists empty (reject before state)

- **GIVEN** `app_irsa_s3_buckets = []` and `app_irsa_sqs_queues = []`
- **WHEN** Terraform plans the cluster folder
- **THEN** no `aws_iam_policy.s3_sqs_admin` instance and no `aws_iam_role_policy_attachment.attach_admin` instance is planned
- **AND** `aws_iam_role.app_irsa` is still planned with the name `eyelevel-s3-sqs-worker-irsa`

#### Scenario: Existing policy moves to its indexed address unchanged

- **GIVEN** a state holding today's `aws_iam_policy.s3_sqs_admin` and `aws_iam_role_policy_attachment.attach_admin` at unindexed addresses, and an `env.tfvars` without the settings
- **WHEN** `terraform plan -refresh=false` runs with this change
- **THEN** the plan reports both objects moved to index `[0]`
- **AND** neither object is planned for create, delete or replace, and the policy document is unchanged

### Requirement: Cluster API allowed ranges

When `cluster_endpoint_public_access_cidrs` is set, the EKS module SHALL receive that list as its `cluster_endpoint_public_access_cidrs` input, with `cluster_endpoint_private_access = true` and `cluster_endpoint_public_access = true` unchanged. When it is absent, the module SHALL receive `["0.0.0.0/0"]`, the pinned module's own default. The variable's validation SHALL reject an empty list and any entry that Terraform cannot parse as a CIDR range, and SHALL be written as a conditional expression (`null ? true : ...`) so it evaluates correctly on Terraform 1.9.8, the version CI pins.

Invariant: a range list reaches the EKS endpoint only when it is non-empty and every entry parses as a CIDR range; an absent setting is never rejected.

#### Scenario: Named ranges reach the endpoint input (accept and scope)

- **GIVEN** `cluster_endpoint_public_access_cidrs = ["203.0.113.5/32", "198.51.100.0/24"]`
- **WHEN** Terraform plans the cluster folder
- **THEN** the value passed to the module is exactly that list
- **AND** in a real plan the `aws_eks_cluster` resource's `vpc_config` has `public_access_cidrs` equal to that list and `endpoint_private_access = true`

#### Scenario: Empty range list is rejected (reject before state)

- **GIVEN** `cluster_endpoint_public_access_cidrs = []`
- **WHEN** Terraform plans the cluster folder
- **THEN** the plan fails on this variable's validation and no resource is planned

#### Scenario: Bare address without a range is rejected (catches)

- **GIVEN** `cluster_endpoint_public_access_cidrs = ["203.0.113.5"]`, an address that looks right but is not a range
- **WHEN** Terraform plans the cluster folder
- **THEN** the plan fails on this variable's validation and no resource is planned

#### Scenario: Absent setting is not rejected (must not block)

- **GIVEN** `cluster_endpoint_public_access_cidrs` is `null`
- **WHEN** Terraform 1.9.8 plans the cluster folder
- **THEN** the validation passes and the module receives `["0.0.0.0/0"]`

### Requirement: setup-eks asks for the three settings

`terraform/aws/setup-eks` SHALL ask three questions before it checks AWS access, in this order: the allowed address ranges, the S3 buckets, the SQS queues. Answers SHALL be comma- or space-separated and kept exactly as typed (no lowercasing). The script SHALL:

- refuse an empty range answer and any entry that is not an IPv4 range `a.b.c.d/n` (each part 0-255, `n` 0-32), and ask again;
- treat an empty bucket or queue answer as an empty list (no access);
- refuse a bucket or queue entry containing anything other than letters, digits, `.`, `_` and `-`, and ask again;
- show the three answers in its "Please confirm your deployment settings" summary.

Invariant: only answers that passed these checks are ever written to `env.tfvars`.

#### Scenario: Range answer is required and checked before any Terraform run (reject before state)

- **GIVEN** a new install with no `env.tfvars`
- **WHEN** the operator answers the range question with nothing, then with `not-a-range`, then with `203.0.113.5/32, 198.51.100.0/24`
- **THEN** `setup-eks` asks again after each of the first two answers
- **AND** neither refused answer appears in any `env.tfvars` the run writes
- **AND** `cluster_endpoint_public_access_cidrs = ["203.0.113.5/32", "198.51.100.0/24"]` is written

#### Scenario: Enter means none for buckets and queues

- **GIVEN** an operator presses Enter at the bucket and queue questions
- **WHEN** `setup-eks` writes `env.tfvars`
- **THEN** it writes `app_irsa_s3_buckets = []` and `app_irsa_sqs_queues = []`

#### Scenario: Names keep their case and refuse addresses (reject before state)

- **GIVEN** the operator answers the bucket question with `s3://groundx-files`, then with `groundx-files, extract-bucket`, and the queue question with `File-Process,large-file`
- **WHEN** `setup-eks` writes `env.tfvars`
- **THEN** it asked again after `s3://groundx-files` and never wrote it
- **AND** it writes `app_irsa_s3_buckets = ["groundx-files", "extract-bucket"]` and `app_irsa_sqs_queues = ["File-Process", "large-file"]`

### Requirement: setup-eks keeps the settings through both rewrites

Both `env.tfvars` rewrites in `setup-eks` (before the network run and before the cluster run) SHALL write all three settings with the operator's answers.

#### Scenario: Both rewrites carry all three settings

- **GIVEN** a `setup-eks` run with answers for all three questions
- **WHEN** the network folder's `terraform plan` runs and later the cluster folder's `terraform plan` runs
- **THEN** the `env.tfvars` each plan reads contains all three settings with the answered values
- **AND** the run ends with `VPC and Cluster setup complete`

### Requirement: setup-eks confirms before changing an existing install

When `terraform/aws/env.tfvars` already exists when `setup-eks` starts, the script SHALL, after the three questions and before any `aws` or `terraform` call, show for each setting what the existing file has (the setting's presence, or the plain-language meaning of its absence) and what it will become, and SHALL continue only when the operator types `yes` (letter case and surrounding spaces ignored). The confirmation SHALL also say that continuing replaces `env.tfvars` with a new file built from the script's template, so the operator's own edits to it are replaced or removed, that the network and cluster changes are then applied without stopping for a plan review, and that an install with an edited `env.tfvars` should instead follow the plan-first steps in `docs/eks-access-scoping.md`. Any other answer, including end of input, SHALL stop with a non-zero exit, leave `env.tfvars` byte-for-byte unchanged, and write no chart values file. A run that started with no `env.tfvars` SHALL NOT show this confirmation.

#### Scenario: Declining leaves the install untouched (reject before state)

- **GIVEN** an existing `env.tfvars`
- **WHEN** the operator answers the three questions and then types `no`
- **THEN** the confirmation shown before the answer says `env.tfvars` is replaced from the template, names `node_diagnostics` among the settings a rewrite loses, says it applies without stopping for a plan review, and points to `docs/eks-access-scoping.md`
- **AND** `setup-eks` exits non-zero
- **AND** `env.tfvars` is byte-for-byte unchanged, no `terraform` or `aws` command ran, and neither `src/groundx/values.aws.local.yaml` nor `src/groundx/prereqs/storageclass/values.aws.local.yaml` was written

#### Scenario: Typing yes continues with the new values

- **GIVEN** an existing `env.tfvars` without the three settings
- **WHEN** the operator answers the questions, presses Enter at the bucket question, and types `yes`
- **THEN** the change list says S3 access is now every bucket in the account and will become none
- **AND** both rewrites carry `app_irsa_s3_buckets = []` and the other two answers, and the run completes

#### Scenario: New install sees no confirmation

- **GIVEN** no `env.tfvars` exists
- **WHEN** `setup-eks` runs to completion
- **THEN** its output does not contain the existing-install change list

### Requirement: Operator documentation for the settings

The repository SHALL document, in `docs/eks-access-scoping.md` linked from the README's Terraform section: the three settings and their states; that direct Terraform runs (`bin/environment eks`) keep today's access unless the settings are added; how an existing install opts in (add the settings, review `terraform -chdir=terraform/aws/eks plan`, then apply); that the `eyelevel:s3-sqs-worker` service account must carry this install's own role ARN; how to recover from a cluster API lockout with `aws eks update-cluster-config ... --resources-vpc-config endpointPublicAccess=true,publicAccessCidrs=...,endpointPrivateAccess=true` and then bring `env.tfvars` in line; and how to return to an older release whose code has no `count` on the policy.

#### Scenario: Documentation carries the operator steps

- **GIVEN** the repository at this change
- **WHEN** a reader opens `docs/eks-access-scoping.md`
- **THEN** it names all three settings, the opt-in steps, the service-account role binding, the lockout recovery command and the older-release step
- **AND** the README's Terraform section links to it
