## Why

A GroundX install created with the bundled AWS Terraform gets two unsafe defaults. The application role `eyelevel-s3-sqs-worker-irsa`, which every GroundX pod on the `eyelevel:s3-sqs-worker` service account assumes, is allowed `s3:*` and `sqs:*` on every resource in the AWS account (`terraform/aws/eks/irsa.tf:33-47` at `5a0ebb10`). The cluster's public API endpoint is turned on with no allowed-address list (`terraform/aws/eks/eks.tf:478-479`), so the pinned EKS module (v20.37.2) passes its own default of `["0.0.0.0/0"]` and the API accepts requests from the whole internet. GX-184 (part of GX-109, a non-engineer installing a secured GroundX on AWS) asks that installs created through `setup-eks` come out limited to their own buckets, queues and chosen address ranges, while an existing install that re-runs the Terraform without new settings keeps working exactly as it does now.

## What Changes

- **Three optional Terraform settings** in `terraform/aws/variables.tf`, the file both the network (`vpc`) and cluster (`eks`) folders read through the shared `env.tfvars`. Proposed names (design freezes them): `app_irsa_s3_buckets`, `app_irsa_sqs_queues`, `cluster_endpoint_public_access_cidrs`. Each is a list of strings with no value by default, so "not set" and "empty list" are different states.
- **S3 and SQS access, decided independently, three states each:**
  - Not set: the role keeps today's statement for that service, rendered exactly as now (same data source and resource names, `FullS3`/`FullSqs` statement IDs, S3 before SQS).
  - Empty list: no statement for that service.
  - Names: access only to the named resources. Buckets get `s3:ListBucket` and `s3:GetBucketLocation` on the bucket, and `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`, `s3:PutObjectTagging` and `s3:AbortMultipartUpload` on its objects. Queues get `sqs:SendMessage`, `sqs:ReceiveMessage`, `sqs:DeleteMessage`, `sqs:ChangeMessageVisibility`, `sqs:GetQueueAttributes` and `sqs:GetQueueUrl` on each queue's full ARN, built from the install's own AWS account and `environment.region`.
  - Both lists empty: the role is kept, and the S3/SQS policy and its attachment are not created. An explicit `moved` block carries an existing install's policy to its new address, so adding this option does not replace the policy.
- **Cluster API allowed ranges:** when set, the EKS module receives the list as `cluster_endpoint_public_access_cidrs` and private endpoint access stays on. When not set, the module receives `["0.0.0.0/0"]`, its own default, so the endpoint is unchanged. The list must not be empty and every entry must be a valid CIDR range; the check is written to evaluate correctly on Terraform 1.9.8, the version CI pins (`.github/workflows/helm-tests.yml:33`).
- **`setup-eks` questions:** the API ranges (typed by the operator, at least one, each checked before any Terraform run, with a reminder to include the public address of the machine running the install; no automatic address lookup), the S3 buckets (naming a separate extraction bucket if one is used; Enter means none) and the SQS queues (every enabled queue, naming the post-process and large-file queues; Enter means none). Answers are plain names; queues are in the install's own region and account. `setup-eks` writes all three settings into both of its `env.tfvars` rewrites (`terraform/aws/setup-eks:131` and `:241`).
- **`setup-eks` on an existing install:** when `env.tfvars` already exists, `setup-eks` shows what will change for the role's S3/SQS access and the API endpoint and requires the operator to type `yes` before it checks AWS access (`setup-eks:51`) or looks up the cluster version (`setup-eks:125`). Any other answer stops with no Terraform or AWS call and leaves `env.tfvars` untouched.
- **`bin/shared/cli-input`:** a new answer type that keeps the operator's text as typed, because `prompt_input` lowercases every answer (`bin/shared/cli-input:58`).
- **Tests:** new runs in the existing `terraform/aws/eks/tests/node_diagnostics.tftest.hcl`, which CI already runs (`helm-tests.yml:40`), and one behavioral script under `bin/tests/` reusing `fake-terraform` and `fake-aws`. No new CI workflow.
- **Docs:** the README Terraform/EKS sections and a new `docs/` page in the style of `docs/eks-node-diagnostics.md`, covering the settings, the opt-in for existing installs, and recovery from a cluster API lockout.
- No breaking change: an `env.tfvars` without the new settings keeps today's policy and endpoint.

## Capabilities

### New Capabilities
- `eks-access-scoping`: the three settings and their states; the IAM statements the role receives for named buckets and queues; the cluster API allowed ranges and their validation; the `setup-eks` questions, both rewrites, and the confirmation on an existing install; the documented opt-in and lockout recovery.

### Modified Capabilities
None. `eks-cluster-version-config` still governs the version `setup-eks` writes; the new confirmation runs before that lookup but does not change what it writes.

## Blast radius, environments and rollout

- **Nothing is applied by merging.** This Terraform changes AWS only when an operator runs `setup-eks` or `bin/environment`, whose `deploy` runs `terraform plan` and `terraform apply --auto-approve` (`bin/shared/util:23-38`). No dev, staging or production environment redeploys because of this change.
- **Who sees a difference:**
  - An existing install that runs the Terraform directly without the new settings: no change to the role policy or the endpoint. Proof is a real `terraform plan` of the old and new code against the same existing-shaped `env.tfvars`, plus a plan against a hand-written state holding today's policy to show the address move with no policy change.
  - An existing install that re-runs `setup-eks`: sees the change list and must type `yes`; its answers are its opt-in.
  - A new install through `setup-eks`: gets scoped access and limited API ranges.
- **Data and stateful resources:** no S3 bucket or SQS queue is created, changed or deleted, and no data moves. On opt-in, the IAM policy is updated in place, or removed with its attachment when both lists are empty (the role stays). The EKS cluster's endpoint access settings are updated in place on opt-in.
- **What could break after opting in:**
  - A bucket or queue left off the list: that install's GroundX pods get access-denied errors on it. The failure is loud and limited to that install.
  - A range list that leaves out the operator's machine: Terraform's in-apply Helm release (`terraform/aws/eks/autoscaler.tf:55-65`) and the operator's `kubectl`/`helm` cannot reach the cluster API.
  - An `env.tfvars` carrying the new settings run against older code that does not declare them: `setup-eks` stops on any Terraform warning (`setup-eks:163`). The Harness guides that describe these settings are held until a groundx-on-prem release declares them.
- **Rollback and rollforward:**
  - Per install: remove a setting from `env.tfvars` and re-run the cluster Terraform to return that setting to today's behavior; correct a wrong name or range and re-run to roll forward.
  - Lockout: restore API access through the AWS EKS API (`aws eks update-cluster-config ... --resources-vpc-config endpointPublicAccess=true,publicAccessCidrs=...,endpointPrivateAccess=true`), then update `env.tfvars` so the next Terraform run does not undo it.
  - Code revert: remove the new settings from `env.tfvars` first. How older code treats a state whose policy sits at the new address is checked in design.

## Open design questions

None. The requester settled the behavior in the approved brainstorm (address entry typed by the operator, Enter means none, plain names, settings absent means today, `yes` confirmation on an existing install). Prompt order, wording and the final setting names are implementation choices for design.

## Impact

- **Code:** `terraform/aws/variables.tf`, `terraform/aws/eks/irsa.tf`, `terraform/aws/eks/eks.tf`, `terraform/aws/setup-eks`, `bin/shared/cli-input`.
- **Tests:** `terraform/aws/eks/tests/node_diagnostics.tftest.hcl` (new runs), a new script in `bin/tests/`.
- **Docs and specs:** `README.md`, a new `docs/` page, a new `eks-access-scoping` capability spec.
- **Unchanged:** the Helm chart (`src/groundx/`), the `helm/` mirror, `values.schema.json`, CI workflows, and the service-account prerequisite chart.
- **Consumers of the new settings:**
  - `groundx-studio-harness`: its `groundx-on-prem` skill guides document the settings, the opt-in, the service-account role binding and lockout recovery. That is the next change in this feature, built after this one and merged only once a groundx-on-prem release declares the settings.
  - `groundx-agent-harness`: regenerated from `groundx-studio-harness`, never edited.
  - GroundX workloads that use the role (cashbot-go, ai-server and the groundx-python extract image): no code change. Their AWS access narrows only for an install that sets names.
- **Out of scope:** the ticket's list holds. That covers creating buckets or queues, changing chart storage or queue settings, forcing existing installs onto the settings, customer-managed KMS keys, permissions for Cognito, CloudFront or workspace managed data, OpenSearch credentials and API TLS, Azure and GCP. It also excludes cross-account or cross-region queues and any setting for reaching the API through the private endpoint from inside the VPC or over VPN.
