# EKS Access Scoping

Three optional Terraform settings limit what a GroundX install on AWS can reach:
which S3 buckets and SQS queues the GroundX application role may use, and which
internet addresses may reach the cluster's control API (the endpoint `kubectl`
and `helm` talk to). Each setting is left out by default, and leaving it out
keeps today's access.

`terraform/aws/setup-eks` asks for all three values on a new install and writes
them to `terraform/aws/env.tfvars`. Direct Terraform runs, including
`bin/environment eks`, keep today's access until you add the settings yourself.

## Settings

Set them at the top level of `terraform/aws/env.tfvars`:

```hcl
app_irsa_s3_buckets                  = ["groundx-files", "extract-bucket"]
app_irsa_sqs_queues                  = ["file-process", "large-file"]
cluster_endpoint_public_access_cidrs = ["203.0.113.5/32"]
```

`app_irsa_s3_buckets` and `app_irsa_sqs_queues` each have three states, decided
separately:

| Value | Role access for that service |
| --- | --- |
| Not set | Every bucket (`s3:*` on `*`) or every queue (`sqs:*` on `*`), as before |
| `[]` | None |
| Names | Only the named buckets or queues |

Named buckets get `s3:ListBucket` and `s3:GetBucketLocation` on each bucket, and
`s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`, `s3:PutObjectTagging` and
`s3:AbortMultipartUpload` on the objects in it. Named queues get
`sqs:SendMessage`, `sqs:ReceiveMessage`, `sqs:DeleteMessage`,
`sqs:ChangeMessageVisibility`, `sqs:GetQueueAttributes` and `sqs:GetQueueUrl`,
and must be in the same AWS account and region as the cluster. If both lists are
`[]`, Terraform attaches no S3 or SQS policy to the role; the role itself stays.

List every bucket and queue the install uses: `file.bucketName` and, if set,
`extract.file.bucketName` in your GroundX Helm values, and the last part of each
`stream.topics.<name>.url` whose type is `sqs`. A missing name makes GroundX fail
with "access denied" errors on that bucket or queue.

`cluster_endpoint_public_access_cidrs` lists the address ranges allowed to reach
the cluster's public API endpoint, for example `203.0.113.5/32` for one address.
When it is set, only those ranges can reach the public endpoint, and the private
endpoint stays on so nodes and pods inside the VPC keep reaching the API
([Configure endpoint access](https://docs.aws.amazon.com/eks/latest/userguide/config-cluster-endpoint.html)).
When it is not set, the endpoint accepts all addresses, as before. It cannot be
an empty list. Include the public address of the computer that runs Terraform and
Helm, or that computer is locked out.

The private endpoint needs the VPC to have `enableDnsHostnames` and
`enableDnsSupport` set to `true` and `AmazonProvidedDNS` in its DHCP options
([Cluster API server endpoint](https://docs.aws.amazon.com/eks/latest/userguide/cluster-endpoint.html)).
The VPC that `setup-eks` creates meets this. If you bring your own VPC, check it
before limiting the addresses.

## Existing installs

Nothing changes for an existing install until you add the settings. Opt in from
a checkout whose `terraform/aws/variables.tf` declares them: older code drops or
ignores them (see [Returning to an older release](#returning-to-an-older-release)).
To opt in:

1. Add the settings to `terraform/aws/env.tfvars`.
2. Review the plan:

   ```bash
   terraform -chdir=terraform/aws/eks plan
   ```

   Check that it changes only the S3/SQS policy, its attachment and the
   cluster's endpoint access, and that it does not replace the cluster or any
   node group. The first plan after this change also reports the S3/SQS policy
   and its attachment as moved to `[0]`. If both lists are `[]`, the plan
   removes the policy and its attachment.
3. Apply only after the plan looks right:

   ```bash
   terraform -chdir=terraform/aws/eks apply
   ```

Do not use `bin/environment eks` to opt in: it applies without waiting for you
to review the plan.

Re-running `setup-eks` on a folder that already has `env.tfvars` asks the three
questions, shows what will change, and continues only if you type `yes`. It
rewrites the whole `env.tfvars` file.

## Service account

GroundX pods use the AWS role through the `eyelevel:s3-sqs-worker` service
account, whose `eks.amazonaws.com/role-arn` annotation must name this install's
role
([IAM roles for service accounts](https://docs.aws.amazon.com/eks/latest/userguide/associate-service-account-role.html)).
The `rolearn` value in `src/groundx/prereqs/serviceaccount/values.yaml` is an
example, not your install's role; replace it with your role's ARN:

```bash
aws iam get-role --role-name eyelevel-s3-sqs-worker-irsa --query Role.Arn --output text
```

([get-role](https://docs.aws.amazon.com/cli/latest/reference/iam/get-role.html))

## After apply

These read-only commands show what AWS now enforces. The cluster name comes from
`terraform -chdir=terraform/aws/eks output -raw cluster_name`.

```bash
aws eks describe-cluster --region REGION --name CLUSTER_NAME \
  --query cluster.resourcesVpcConfig.publicAccessCidrs
aws iam list-attached-role-policies --role-name eyelevel-s3-sqs-worker-irsa
aws iam get-policy --policy-arn POLICY_ARN --query Policy.DefaultVersionId --output text
aws iam get-policy-version --policy-arn POLICY_ARN --version-id VERSION_ID \
  --query PolicyVersion.Document
```

([describe-cluster](https://docs.aws.amazon.com/cli/latest/reference/eks/describe-cluster.html),
[list-attached-role-policies](https://docs.aws.amazon.com/cli/latest/reference/iam/list-attached-role-policies.html),
[get-policy](https://docs.aws.amazon.com/cli/latest/reference/iam/get-policy.html),
[get-policy-version](https://docs.aws.amazon.com/cli/latest/reference/iam/get-policy-version.html))

If the addresses still show `0.0.0.0/0` or the policy still allows `s3:*` or
`sqs:*` on `*` after you set the values, compare the setting names in
`env.tfvars` with the names above.

## Lockout recovery

If your address changes or is missing from the list, `kubectl`, `helm` and
Terraform's Helm releases can no longer reach the cluster. Restore access with
the AWS CLI commands AWS documents for changing endpoint access
([Configure endpoint access](https://docs.aws.amazon.com/eks/latest/userguide/config-cluster-endpoint.html)):

```bash
aws eks update-cluster-config --region REGION --name CLUSTER_NAME \
  --resources-vpc-config endpointPublicAccess=true,publicAccessCidrs="203.0.113.5/32",endpointPrivateAccess=true
aws eks describe-update --region REGION --name CLUSTER_NAME --update-id UPDATE_ID
```

Use your current public address in place of `203.0.113.5/32`, and add every
other range that should keep access. The update is done when `describe-update`
shows the status `Successful`.

Then put the same list in `cluster_endpoint_public_access_cidrs` in
`terraform/aws/env.tfvars` and run `terraform -chdir=terraform/aws/eks plan`.
The plan must show no change to the cluster's endpoint access; otherwise the
next apply puts back the old list.

## Returning to an older release

Releases before this change do not know these settings. An older `setup-eks`
rewrites `env.tfvars` from its own template, so it silently drops all three. A
direct Terraform run of older code, including `bin/environment eks`, warns that
the settings are undeclared and ignores them. Either way the role gets full S3
and SQS access again and the endpoint opens to all addresses. Use the read-only
commands in [After apply](#after-apply) to see what AWS enforces.

Run `terraform -chdir=terraform/aws/eks plan` before applying. If it shows the
S3/SQS policy or its attachment being destroyed and created, move them back
first, then plan again:

```bash
terraform -chdir=terraform/aws/eks state mv 'aws_iam_policy.s3_sqs_admin[0]' aws_iam_policy.s3_sqs_admin
terraform -chdir=terraform/aws/eks state mv 'aws_iam_role_policy_attachment.attach_admin[0]' aws_iam_role_policy_attachment.attach_admin
```

If the plan shows them only as moved, no extra step is needed.
