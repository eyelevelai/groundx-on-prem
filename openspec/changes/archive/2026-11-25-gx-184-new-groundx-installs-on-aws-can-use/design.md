Motivation and blast radius are in `proposal.md`; required behavior is in `specs/eks-access-scoping/spec.md`. This document records how the change is built and why.

## Goals / Non-Goals

**Goals:**
- Three optional `env.tfvars` settings that limit the application role to named S3 buckets and SQS queues and the cluster API to named address ranges, each with "not present" meaning today's behavior.
- `setup-eks` asks for the three values, writes them in both of its `env.tfvars` rewrites, and asks for a typed `yes` before it changes an existing install.
- An existing install that does nothing sees no change to the role policy or the endpoint.

**Non-Goals:**
- Creating buckets or queues, changing chart values, forcing existing installs onto the settings, KMS grants, Cognito/CloudFront/managed-data permissions, cross-account or cross-region queues, an automatic public-address lookup, a setting for the private endpoint's security group, and IPv6 range entry in `setup-eks`.
- Validating bucket and queue names in Terraform (only `setup-eks` checks them; a wrong name on a direct run fails loudly with AccessDenied for that install).
- Fixing the unrelated findings listed at the end.

## Decisions

### 1. Setting names (frozen)

`app_irsa_s3_buckets`, `app_irsa_sqs_queues`, `cluster_endpoint_public_access_cidrs`, each `list(string)` with `default = null`, declared at the end of `terraform/aws/variables.tf`. The Harness guides document these exact names.

- `app_irsa_*` matches the existing resource names in `terraform/aws/eks/irsa.tf:27` (`aws_iam_role.app_irsa`), so a reader can follow a setting to the role it changes.
- `cluster_endpoint_public_access_cidrs` is the pinned EKS module's own input name (module v20.37.2 `variables.tf:107`), so the setting reads as a pass-through.
- Alternative rejected: optional attributes on the existing `environment` or `cluster` objects. `environment` is required and strict (`terraform/aws/variables.tf:3-17`), `cluster` is written by `setup-eks` only when `SEARCH=false` (`terraform/aws/setup-eks:261-264`), and a hand-writer copying either block would have to carry the access settings inside it. Separate top-level variables follow the repo's optional-setting pattern (`node_diagnostics`, `dns_observability`, `eks_kms_source_policy_documents` at `terraform/aws/variables.tf:27-47`).
- `env.tfvars.example` is not changed. `setup-eks` overwrites the copied example in its first rewrite (`setup-eks:131`), and an operator who copies the example for a direct run must keep today's access until they add the settings themselves.

### 2. Variable declarations and the range check on Terraform 1.9.8

```hcl
variable "cluster_endpoint_public_access_cidrs" {
  type    = list(string)
  default = null

  validation {
    condition = var.cluster_endpoint_public_access_cidrs == null ? true : (
      length(var.cluster_endpoint_public_access_cidrs) > 0 &&
      alltrue([for c in var.cluster_endpoint_public_access_cidrs : can(cidrhost(c, 0))])
    )
    error_message = "cluster_endpoint_public_access_cidrs must list at least one address range such as 203.0.113.5/32. Remove the setting to keep the endpoint open to all addresses."
  }
}
```

- The `null` case is handled by the conditional's first branch, so the check does not depend on whether `||` or `&&` short-circuit on the Terraform version that runs it. Inside the selected branch the list is non-null, so both operands of `&&` are safe to evaluate. Task 1.4 runs the test file on Terraform 1.9.8, the version CI pins (`.github/workflows/helm-tests.yml:33`).
- `can(cidrhost(c, 0))` accepts any range Terraform parses (IPv4 or IPv6) and rejects a bare address such as `203.0.113.5`. Whether AWS accepts a given range (for example IPv6 on an IPv4 cluster) is left to the EKS API at apply.
- The repository declares `required_version = ">= 1.0.0"` (`terraform/shared/versions.tf`). That floor is already below what the repo uses (`optional()` needs 1.3, the existing tests' `mock_provider` needs 1.7); this change adds nothing newer than `moved` (1.1). The binding version is CI's 1.9.8, so a task runs the test file on a 1.9.8 binary.
- `app_irsa_s3_buckets` and `app_irsa_sqs_queues` have no validation block (see Non-Goals).

### 3. The IRSA policy

All in `terraform/aws/eks/irsa.tf`, keeping every existing name:

```hcl
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  app_irsa_s3_statements = var.app_irsa_s3_buckets == null ? [
    { sid = "FullS3", actions = ["s3:*"], resources = ["*"] },
  ] : length(var.app_irsa_s3_buckets) == 0 ? [] : [
    { sid = "S3Buckets", actions = ["s3:ListBucket", "s3:GetBucketLocation"], resources = [<bucket ARNs>] },
    { sid = "S3Objects", actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:PutObjectTagging", "s3:AbortMultipartUpload"], resources = [<bucket ARNs>/*] },
  ]
  app_irsa_sqs_statements = <same three-way shape; FullSqs on "*", or SqsQueues on queue ARNs>
  app_irsa_statements     = concat(local.app_irsa_s3_statements, local.app_irsa_sqs_statements)
}

data "aws_iam_policy_document" "s3_sqs_admin" {
  count = length(local.app_irsa_statements) > 0 ? 1 : 0
  dynamic "statement" {
    for_each = local.app_irsa_statements
    content {
      sid       = statement.value.sid
      effect    = "Allow"
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_policy" "s3_sqs_admin" { count = <same>; ... policy = data.aws_iam_policy_document.s3_sqs_admin[0].json }
resource "aws_iam_role_policy_attachment" "attach_admin" { count = <same>; ... policy_arn = aws_iam_policy.s3_sqs_admin[0].arn }

moved {
  from = aws_iam_policy.s3_sqs_admin
  to   = aws_iam_policy.s3_sqs_admin[0]
}
moved {
  from = aws_iam_role_policy_attachment.attach_admin
  to   = aws_iam_role_policy_attachment.attach_admin[0]
}
```

- **Byte-identical when absent.** The data source keeps its name and receives the same two statements in the same order (`FullS3` then `FullSqs`, Sid, Effect, one action, resource `*`) as today's static blocks (`irsa.tf:34-47`), so the provider renders the same JSON. This is proven by a real plan of the old and new code against the same `env.tfvars` (task 3.2), not by reading code.
- **ARNs.** Buckets: `arn:${data.aws_partition.current.partition}:s3:::<name>` and `.../<name>/*`. Queues: `arn:${partition}:sqs:${var.environment.region}:${data.aws_caller_identity.current.account_id}:<name>` (queues are in the install's own region and account, brainstorm D3).
- **Action list.** From the planner's read of every caller of this role (decomposition v1, evidence 1): cashbot-go's S3 client (multipart upload manager with abort on failure, `CopyObject`, `DeleteObjects`, `ListObjectsV2`, tagged `PutObject`, `GetObject`, presigned GET/HEAD/PUT) and SQS client (`ReceiveMessage`, `DeleteMessage`, `ChangeMessageVisibility`, `GetQueueAttributes`, `SendMessageBatch`); ai-server (`get_object`, `put_object`, `get_queue_by_name`, `send_message`); the groundx-python extract image (`get_object`, `head_object`, tagged `put_object`). AWS authorizes these through the listed actions: multipart create/part/complete through `s3:PutObject` and abort through `s3:AbortMultipartUpload`; `CopyObject` through `s3:GetObject` on the source and `s3:PutObject` on the destination; `HeadObject` through `s3:GetObject`; `ListObjectsV2` through `s3:ListBucket`; `DeleteObjects` through `s3:DeleteObject`; the SQS batch calls through their single-message actions; presigned URLs through the signing role's own permissions (Amazon S3 User Guide "Multipart upload API and permissions" and "Sharing objects with presigned URLs"; S3 API Reference `CopyObject`, `HeadObject`, `ListObjectsV2`, `DeleteObjects`; SQS Developer Guide "Amazon SQS batch actions" and the API permissions reference). `s3:ListMultipartUploadParts` and `s3:ListBucketMultipartUploads` are not added: no caller lists parts or uploads. `s3:GetObjectTagging` is not added: no current copy path copies a tagged object (planner evidence R2); the on-cluster document-copy check confirms.
- **Both lists empty (brainstorm D11).** `count = 0` on the data source, the policy and the attachment; the role stays. The data source carries the same `count` so the provider is never asked to render a policy with no statements.
- **Address move.** Adding `count` to a resource that had none moves its object to `[0]`: Terraform's refactoring guide says "When you add count to an existing resource that didn't previously have the argument, Terraform automatically proposes moving the original object to instance 0 unless you write a moved block that explicitly mentions that resource. However, we recommend writing out the corresponding moved block explicitly" (https://developer.hashicorp.com/terraform/language/modules/develop/refactoring, "Enable count or for_each for a resource"). The explicit blocks follow that recommendation. For an install that sets both lists empty, the moved object lands at `[0]`, which is no longer declared, so Terraform plans to destroy the policy and attachment; that is the intended opt-in result.
- **Code-revert path.** The same guide documents only the forward direction, and warns that "Removing a moved block is a breaking change because any configurations that refer to the old address will plan to delete the existing object instead of move it." An older release has neither `count` nor the moved blocks, so its behavior on a state holding `aws_iam_policy.s3_sqs_admin[0]` is not documented there. Decision: do not rely on it. The docs tell an operator returning to an older release to run `terraform plan` first and, if it shows the S3/SQS policy or attachment being destroyed and created, to run `terraform -chdir=terraform/aws/eks state mv 'aws_iam_policy.s3_sqs_admin[0]' aws_iam_policy.s3_sqs_admin` and the same for `aws_iam_role_policy_attachment.attach_admin`, then plan again. Task 3.4 records what the older code plans with and without those commands and proves that after those commands the older code plans no create, delete or policy change for them.
- **Test visibility.** The existing test overrides this data source's JSON (`tests/node_diagnostics.tftest.hcl:26-31`), so the committed runs assert `local.app_irsa_statements` (compared with `jsonencode`, which is insensitive to list-versus-tuple typing) and the `count` of the policy and attachment. The rendered JSON is asserted only by the saved real plans.

### 4. The endpoint input

In the `locals` block at the top of `terraform/aws/eks/eks.tf`:

```hcl
cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs == null ? ["0.0.0.0/0"] : var.cluster_endpoint_public_access_cidrs
```

and in `module "eyelevel_eks"` (`eks.tf:463`) one new line, `cluster_endpoint_public_access_cidrs = local.cluster_endpoint_public_access_cidrs`. `cluster_endpoint_private_access = true` and `cluster_endpoint_public_access = true` (`eks.tf:475-476`) stay as they are.

- `["0.0.0.0/0"]` is the module's own default (v20.37.2 `variables.tf:107-111`), which the module passes straight into `vpc_config.public_access_cidrs` (`main.tf:69-71`), so the absent case is the same configuration an existing cluster was created with. `null` was rejected: it would also plan no change, but it is not literally the same input.
- Private access is already on today, so nodes and pods inside the VPC keep reaching the API through the private endpoint when the public list is narrowed. AWS's private-endpoint requirement is `enableDnsHostnames` and `enableDnsSupport` set to `true` and `AmazonProvidedDNS` in the DHCP options (EKS user guide, "Cluster API server endpoint"). The VPC `setup-eks` creates meets the first two: `terraform/aws/vpc/vpc.tf:22` sets `enable_dns_hostnames = true`, and VPC module v5.8.1 (`vpc.tf:10`) defaults `enable_dns_support = true` (`variables.tf:47-51` at tag `v5.8.1`). It does not create a custom DHCP options set (`enable_dhcp_options` defaults to `false`, `variables.tf:123-127`). A bring-your-own VPC on a direct run is the operator's responsibility; the docs say so in one line.

### 5. setup-eks

**Order.** The three questions are asked after the prompt texts are built (`setup-eks:37-44`) and before the AWS check (`setup-eks:50-52`), in the order: ranges, buckets, queues. Existing-install detection is a flag set before the example is copied (`setup-eks:15-18`). When the flag is set, the change list and the `yes` confirmation follow the three questions, still before `test_aws` and before `resolve_setup_eks_version` (`setup-eks:125`). Asking first lets the change list show the real new values, and none of the three questions needs AWS or the region (queue ARNs are built by Terraform from `environment.region`). The existing deployment-settings summary (`setup-eks:87-105`) gains three lines showing the answers.

**Answer handling.** `bin/shared/cli-input` gains two `prompt_input` types, `cidr-list` and `name-list`. Both skip the lowercasing at `cli-input:58`, split the answer on commas and spaces, and print an HCL list literal (`["a", "b"]`, or `[]`) for the heredocs. `cidr-list` refuses an empty answer and any entry that is not `a.b.c.d/n` with each part 0-255 and `n` 0-32. `name-list` accepts an empty answer as `[]` and refuses any entry with characters other than letters, digits, `.`, `_` and `-`; this allowlist covers S3 bucket and SQS queue names and also keeps quotes and `${` out of the generated HCL. On a refused answer, `prompt_input` re-asks with the type's error text. The confirmation uses a plain `read -r` (not `prompt_input`), so end of input stops the script instead of looping. New code uses only bash 3.2 features (macOS `/bin/bash`): `tr` for case, no `mapfile`, `declare -A` or `${var,,}`.

**Rewrites.** Both heredocs (`setup-eks:131-149` and `:241-259`) end with:

```hcl
app_irsa_s3_buckets                  = ["groundx-files", "extract-bucket"]
app_irsa_sqs_queues                  = ["File-Process", "large-file"]
cluster_endpoint_public_access_cidrs = ["203.0.113.5/32"]
```

**Final prompt text** (two-reader test: a non-technical operator knows what to type and why; a developer new to GroundX sees the exact setting and chart value). No external lookup service is named: a primary source for one was not found, so the text sends the operator to their network administrator or a web search.

Ranges:

```
Which internet addresses may manage this cluster?

Your cluster has a control address that tools like kubectl and helm use to manage it.
Only the addresses you list here can reach it. Everyone else is refused.

Include the public address of THIS computer, because this script and the GroundX
install that follows manage the cluster from here. If you leave it out, this computer
is locked out. To find it, ask your network administrator, or search the web for
"what is my IP address" on this computer.

Write each address with /32 at the end, for example 203.0.113.5/32. To allow a whole
office network, use its range, for example 203.0.113.0/24. Separate several with commas.
This answer is saved as cluster_endpoint_public_access_cidrs in terraform/aws/env.tfvars.
```

Input line `Allowed addresses: `. On a refused answer: `Enter at least one address with /32 at the end, like 203.0.113.5/32 (separate several with commas): `.

Buckets:

```
Which S3 buckets will GroundX store files in?

GroundX can read and write only the buckets you list here. List every bucket this
install uses: the main file bucket and, if document extraction uses its own bucket,
that bucket too. Type bucket names only, for example groundx-files, separated by commas.

Press Enter without typing anything if this install keeps its files inside the cluster
(the GroundX default) and uses no S3 bucket. GroundX then gets no S3 access.

In your GroundX Helm values these are file.bucketName and, if set, extract.file.bucketName.
This answer is saved as app_irsa_s3_buckets in terraform/aws/env.tfvars.
```

Input line `S3 bucket names (Enter for none): `. On a refused answer: `Use bucket names only, like groundx-files (no s3:// and no slashes), separated by commas. Enter for none: `.

Queues:

```
Which SQS queues will GroundX use?

GroundX can use only the queues you list here. List every queue this install has
turned on, including the post-process queue and the large-file queue if you use them.
Type queue names only, for example file-process, separated by commas. The queues must
be in this AWS account and in the region you choose next.

Press Enter without typing anything if this install uses the built-in Kafka queues
(the GroundX default) and no SQS queue. GroundX then gets no SQS access.

In your GroundX Helm values each queue is the last part of a stream.topics.<name>.url
whose type is sqs. This answer is saved as app_irsa_sqs_queues in terraform/aws/env.tfvars.
```

Input line `SQS queue names (Enter for none): `. On a refused answer: `Use queue names only, like file-process (no https:// address), separated by commas. Enter for none: `.

Existing-install change list (each "now" line is the absent meaning shown here, or `as set in your current env.tfvars` when a line starting with the setting name exists; each "after" line is the answer, or `none (no S3 access)` / `none (no SQS access)` for an empty list):

```
This folder already has an env.tfvars file, so GroundX may already be installed from it.
Continuing rewrites env.tfvars and changes this install's AWS access:

  S3 buckets GroundX can use
    now:   every bucket in this AWS account (no app_irsa_s3_buckets setting)
    after: groundx-files, extract-bucket
  SQS queues GroundX can use
    now:   every queue in this AWS account (no app_irsa_sqs_queues setting)
    after: none (no SQS access)
  Addresses that can manage the cluster
    now:   any address on the internet (no cluster_endpoint_public_access_cidrs setting)
    after: 203.0.113.5/32

If a bucket or queue this install uses is missing, GroundX will fail with "access denied" errors.
If this computer's public address is missing, this computer loses access to the cluster.

Type yes to continue. Anything else stops without changing anything.
```

Input line `Continue? `. Any answer other than `yes` (case and surrounding spaces ignored) prints `Stopped. Nothing was changed.` and exits 1.

### 6. Tests (committed) and their proportion

- **Mock-provider runs** in the existing `terraform/aws/eks/tests/node_diagnostics.tftest.hcl`, which CI already runs (`helm-tests.yml:40`): file-level `override_data` for `data.aws_partition.current` (`partition = "aws"`) and `data.aws_caller_identity.current` (`account_id = "123456789012"`); runs for absent, named, S3-empty with named queues, SQS-empty with named buckets, S3-empty with SQS absent, both empty, named ranges, an empty range list and a bare address (`expect_failures`). Each run sets all three variables explicitly (absent = `null`), because a developer's own `terraform/aws/env.tfvars` auto-loads into the test and would otherwise leak into the "absent" runs. No new test file and no CI edit.
- **One behavioral script, `bin/tests/setup-eks-access-test`**, reusing `fake-terraform` and `fake-aws` with a new `setup_eks` scenario (the fakes exit 2 on any call they do not expect, so the scenario must be added). It copies `bin/`, `terraform/aws/setup-eks`, `terraform/aws/env.tfvars.example`, empty `terraform/aws/eks` and `terraform/aws/vpc` folders and `src/groundx/prereqs/storageclass/` into a `mktemp -d` tree, pipes answers in, and the fake `terraform` copies `env.tfvars` on every `plan`. Three scenarios: new install, existing install declined, existing install accepted. False-pass rules from the plan gate:
  - fails closed unless `terraform` and `aws` on the run's `PATH` resolve to the fakes and the `setup-eks` under test sits under the test's temp root (`pwd -P` on both), so it never touches the real gitignored `terraform/aws/env.tfvars` or `src/groundx/*.local.yaml`;
  - runs each `setup-eks` in its own process group (`set -m`) with a watchdog that kills the group after a fixed time and writes a marker; a fired watchdog is a failure (`prompt_input` loops forever at end of input, `cli-input:49-71`);
  - asserts exit codes from the process itself and asserts the captured output has no `unexpected terraform invocation` or `unexpected aws invocation` line, because `setup-eks` checks `tee`'s exit status without `pipefail` (`setup-eks:154-156`), so a fake's exit 2 never reaches the script's own check;
  - decline path: `env.tfvars` is byte-identical (`cmp`), no terraform or aws call was logged, and neither chart values file exists; happy paths: exit 0, the `VPC and Cluster setup complete` line, and every `env.tfvars` snapshot carries the three settings with the expected values;
  - an optional `SETUP_EKS_TEST_KEEP=<dir>` copies the snapshots out, so the network-folder evidence (task 3.3) plans the exact file `setup-eks` wrote.
  It is not wired into CI or the pre-push gate, like the existing `bin/tests` scripts. Running it executes files inside this privileged repo, so the local hook asks for approval.
- **Proportion.** Estimated production lines: `variables.tf` about 30, `irsa.tf` about 45 net, `eks.tf` 2, `setup-eks` about 80, `cli-input` about 45, roughly 200 in total. Estimated test lines: about 150 of `tftest` runs, about 180 for the `setup-eks` script and about 30 for the fake scenarios, roughly 360, so about 1.8 test lines per production line. The review re-measures this from the diff. The production estimate is over the review's 150-line functional budget; the Terraform settings and the `setup-eks` questions ship together because the ticket's "new installs are safe" outcome needs both, and either half alone leaves either no way to set the values in `setup-eks` or nothing for them to change.

### 7. Saved real-plan evidence (uncommitted)

Saved under `.sdd-state/GX-184/evidence/` in the workspace, never committed. Runs use the AWS profile the requester approved for read-only plan runs (never `apply`), in a scratch copy of `terraform/aws` with local state, no backend, a scratch `env.tfvars` and `cluster.kube_config_path` pointing at an empty scratch kubeconfig (never `~/.kube/config`, never `bin/environment`). `environment.vpc_id` and `subnets` carry placeholder IDs so the module is planned; no data source in the plan looks them up (planner evidence R4). Each evidence folder stores a SHA-256 of `terraform/aws/variables.tf`, `terraform/aws/eks/irsa.tf` and `terraform/aws/eks/eks.tf` (plus `terraform/aws/setup-eks` for the network-folder run), and each task check refuses evidence whose hash no longer matches the code.

- AC1-AC3 and both-empty: four `plan -out` + `show -json` runs (named buckets, queues and ranges; S3 empty with named queues; SQS empty with named buckets; both empty).
- AC4 (brainstorm D9): the code at the merge base and this change planned against the same existing-shaped `env.tfvars`; policy strings and `vpc_config` endpoint values compared byte for byte.
- AC5: the network folder planned on the first-rewrite `env.tfvars` kept by the `setup-eks` test, with no `Warning` or `Error` line.
- Address move (plan-gate rule 3): a hand-written state holding today's policy and attachment at unindexed addresses, planned with this change and `-refresh=false`; plus the code-revert case from decision 3.

### 8. On-cluster verification after review (not a pipeline task)

AC6 and AC7 need a real cluster built by this Terraform. After review, and only with the requester's explicit authorization for each AWS-mutating step, a throwaway cluster is built fresh on this branch by `setup-eks` from an EC2 runner outside the cluster's VPC, through the spike skill. The validation EKS cluster is never used (requester instruction, 2026-11-25). Steps: create test buckets and queues outside Terraform (named ones plus one unlisted bucket and queue); run `setup-eks` with them and `<runner public IP>/32`; confirm the Terraform apply (including the autoscaler Helm release) and the GroundX Helm install complete from the runner; from a GroundX pod's IRSA identity (not the operator's admin credentials) confirm `sts get-caller-identity` is this role, signed upload and download, a multipart upload, a document copy, a tagged trace write and queue processing succeed, and the unlisted bucket and queue are denied; probe the API from an unlisted address and expect refusal; tear down only on the requester's go-ahead, uninstalling Helm before `terraform destroy`.

### 9. Documentation and the sweep

- New `docs/eks-access-scoping.md` in the style of `docs/eks-node-diagnostics.md` (short sections: what it does, settings, existing installs, after apply, lockout recovery, returning to an older release). It covers the three states per setting, the plan-review-then-apply opt-in for existing installs (`bin/environment eks` applies without a pause, `bin/shared/util:23-38`), the service account `eyelevel:s3-sqs-worker` carrying this install's role ARN (`aws iam get-role --role-name eyelevel-s3-sqs-worker-irsa --query Role.Arn --output text`; the chart's example ARN in `src/groundx/prereqs/serviceaccount/values.yaml:1-3` belongs to another account), the lockout recovery command from the EKS user guide followed by updating `env.tfvars` to the same list and planning to confirm no endpoint change, the decision-3 revert step, and one line that a bring-your-own VPC must meet the private-endpoint DNS requirement.
- README `# Terraform Deployment (terraform/aws/)` gains a short `## Limiting AWS access for EKS installs` section linking the page; `#### Using AWS S3` and `#### Using AWS SQS` each gain one sentence pointing installs made with `setup-eks` to the matching setting.
- `bin/README.md` `eks` component gains one bullet: the three optional settings, absent keeps today's access.
- Sweep (by topic, whole repo: `README.md`, `docs/`, `bin/README.md`, `AGENTS.md`, `CONTRIBUTING.md`, `terraform/**/*.md`) for the IRSA policy, the service account, the cluster endpoint, `setup-eks` prompts and `bin/environment eks`. Places that need the change are the three above. Left unchanged: `README.md:1086-1104` (EKS version adoption; still accurate), `docs/eks-node-diagnostics.md:19` (already says not to use `bin/environment` for production enablement), `docs/agents/private-file-access.md:65-73` and `docs/on-prem-identity.md:43` (IRSA in general, still accurate), `AGENTS.md:65` (privileged-script note), and `terraform/groundx-operator/README.md:290-300`, which describes a path `environment/aws/setup-eks` that does not exist (unrelated finding).

### 10. Pattern capture

`openspec/config.yaml` `context` gains a "CONVENTIONS DISCOVERED DURING GX-184" block: hermetic `tftest` runs set optional variables explicitly; `setup-eks` behavioral tests run a temp copy of the tree with the fakes; Terraform version claims are checked on CI's 1.9.8.

No ADR: each decision is reversible per install and is recorded here and in the spec.

## Existing mechanisms

| New item | Closest existing mechanism (path) | Reuse or extend | Decision |
| --- | --- | --- | --- |
| Three top-level variables | Optional top-level variables `node_diagnostics`, `dns_observability`, `eks_kms_source_policy_documents` (`terraform/aws/variables.tf:27-47`); `environment`/`cluster` objects | Following the top-level pattern; adding attributes to `environment` or `cluster` was compared | Top-level variables (decision 1) |
| Range validation | `validation` blocks in `terraform/shared/variables.tf:127-130` and `terraform/groundx-operator/operator/variables.tf:490,835-850` | Same `validation` mechanism; searched `cidrhost`, `cidr` in `terraform/`: no CIDR check exists | New `validation` block in the same style |
| Endpoint ranges | EKS module input `cluster_endpoint_public_access_cidrs` (module v20.37.2 `variables.tf:107`) | Pass-through of the module's own input | Reused; no new resource |
| Statement locals, dynamic statements, `count` | Existing `data.aws_iam_policy_document.s3_sqs_admin`, `aws_iam_policy.s3_sqs_admin`, `aws_iam_role_policy_attachment.attach_admin` (`irsa.tf:34-57`); the `terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc` module (5.39.0) used by `module.irsa_autoscaler`, `irsa_ebs_csi` and `irsa_efs_csi` (`autoscaler.tf:35-39`, `ebs.tf:5-9`, `efs.tf:60-64`) | Changing the existing resources in place keeps addresses (AC4); the IAM module would create a new role and policy | Existing resources extended; IAM module rejected |
| `data.aws_partition`, `data.aws_caller_identity` | Searched `terraform/` for both: none at the root (the EKS module reads its own internally) | No reachable existing value at the root | New data sources in `irsa.tf` |
| `moved` blocks | Searched `terraform/` for `moved {`: none | Terraform's implicit move would also work | Explicit blocks, per Terraform's guide (decision 3) |
| `cidr-list`/`name-list` answer types | `prompt_input` types `menu`, `text`, `aws-region`, `yn` (`bin/shared/cli-input:24-47`) | Extended with two types; `text` lowercases (`:58`) and validates nothing | Extended, not a new helper |
| Existing-install confirmation | `prompt_input "yn"` deployment confirmation (`setup-eks:107`); searched `bin/`, `terraform/aws`, `src/build.sh` for a typed-`yes` gate: none | `yn` accepts `y`/`n` and loops at end of input; D8 requires typing `yes` and stopping on anything else | Plain `read -r` with a `yes` compare; `yn` left unchanged |
| `bin/tests/setup-eks-access-test`, `setup_eks` fake scenario | `bin/tests/resolve-eks-version-test` with `fake-terraform`/`fake-aws` (scenario switch on `FAKE_SCENARIO`); `.build/bin/verify-storage-contract.py` `verify_setup_eks` (regex scan of the script text) | The regex scan cannot run the script or check both rewrites; the fakes already follow a scenario pattern | New scenario in the existing fakes, one new script beside the existing one |
| `docs/eks-access-scoping.md` | `docs/eks-node-diagnostics.md` (optional Terraform setting page); README `## EKS Cluster Version Configuration` | A README-only section would be long beside the existing short EKS sections | New page in the node-diagnostics style, linked from a short README section |

## Risks / Trade-offs

- [An operator leaves a bucket or queue off the list] → That install gets AccessDenied on it, loudly, while the setting limits the damage of a stolen role to the listed resources. The prompts and docs name the chart values that show what is in use.
- [The operator's address changes, or a range is mistyped] → The cluster API refuses this machine. The docs give the EKS API recovery and say to update `env.tfvars` so the next Terraform run does not undo it.
- [A misspelled setting name on a direct run] → Terraform warns about an undeclared variable and applies today's access; `bin/environment eks` does not stop on warnings. The Harness change adds a read-only post-apply check; this repo's docs show `aws eks describe-cluster --query cluster.resourcesVpcConfig.publicAccessCidrs` and the attached policy.
- [`env.tfvars` with the new settings run against older code] → An older `setup-eks` rewrites `env.tfvars` from its own template before each Terraform run (`setup-eks:131` and `:241` at `5a0ebb10`), so the three settings are silently dropped and the install is applied with today's access. A direct `bin/environment eks` run against older code warns about the undeclared variables and still applies today's access. In both cases the post-apply read-only check in the docs shows the result. The Harness guides are held until a release declares the settings.
- [An existing install re-runs `setup-eks` and accepts] → The rewrite replaces everything else in `env.tfvars` too, as `setup-eks` already does today; the change list states that the file is rewritten.
- [`setup-eks` accepts IPv4 ranges only] → An IPv6-only operator edits `env.tfvars` by hand; Terraform's own check accepts any range it parses.
- [AWS rejects a syntactically valid range at apply (for example a reserved range)] → The apply fails with AWS's message; not validated here.
- [The real-plan evidence goes stale after a later code change] → Each evidence check compares a stored hash of the planned files with the current files and fails on mismatch.

## Migration Plan

- **Rollout.** Nothing is applied by merging. Order: this repository merges and is released; then the held Harness change re-checks its version, re-runs its chart-backed scan against the release tag, and merges. Per install: new installs get the settings through `setup-eks`; an existing install opts in by adding the settings, reviewing `terraform -chdir=terraform/aws/eks plan` and applying. The on-cluster check (decision 8) runs after review and before the release is cut.
- **Blast radius.** Limited to AWS installs managed by this Terraform that opt in: the IAM policy is updated in place (or removed with its attachment when both lists are empty) and the EKS endpoint access is updated in place. No bucket, queue, data, node group or chart resource changes. No environment changes unless someone runs this Terraform against it with the new settings (or re-runs `setup-eks` and types `yes`).
- **Rollback.** Per install: remove a setting and re-apply the cluster folder to return to today's access for it. Lockout: the EKS API command, then `env.tfvars`. Code revert: decision 3's plan-first step.

## Open Questions

- Whether older code moves a state's `[0]` policy back without help. Answered empirically by task 3.4; the documented step is correct either way.
- `s3:GetObjectTagging` on copy: left out; the on-cluster document copy confirms.

## Unrelated findings (not fixed)

- `irsa.tf` indexes `module.eyelevel_eks[0]` although the module has `count = should_create` (`eks.tf:464`); a plan with an empty `vpc_id` or subnets errors.
- `terraform/shared/versions.tf` declares `required_version >= 1.0.0`, below what the code needs.
- The role name `eyelevel-s3-sqs-worker-irsa` has no cluster name in it, so two installs in one account collide.
- `setup-eks` stops on any `Warning` substring in the plan log (`setup-eks:163`).
- `prompt_input` loops forever at end of input (`cli-input:49-71`), and its second `$?` test (`:64`) reads the previous test's status, so the `err_msg_n` message is never shown.
- `terraform/groundx-operator/README.md:297` points to `environment/aws/setup-eks`, which does not exist.
- `openspec/config.yaml` `context` describes the Terraform path as not used for new installs and says no Terraform CI workflow exists; both disagree with `AGENTS.md`, the README Terraform section and `helm-tests.yml:35-40`.

## Amendments

### 2026-11-25: service-account conditions in the operator doc (review fix round 1)

Decision 9 listed the service account carrying this install's role ARN as the doc's only service-account content. Review found that this read as if every GroundX pod uses the role. `docs/eks-access-scoping.md` now states the conditions under which the S3 and SQS settings limit a pod: the role trusts only `eyelevel:s3-sqs-worker` (`terraform/aws/eks/irsa.tf:14-18`); the `src/groundx/prereqs/serviceaccount` chart is installed with this install's role ARN; the GroundX values name that service account, because the chart's service account name defaults to empty (`src/groundx/templates/_helpers/main.tpl:207-210`) and `src/groundx/values/values.aws.services.yaml:13-14` names `existing-service-account`; and the S3 `username` and `password` file values are left unset, because the chart passes them to GroundX as static keys (`src/groundx/templates/resources/config-yaml.yaml:716-723`). Two read-only `kubectl` commands show the annotation and each pod's service account. The same round removed the pre-existing `irsa.tf` comment that called the policy a broad admin policy; no decision here referred to it.

### 2026-11-25: static keys and bucket/queue name validation (review fix round 2)

The round 1 entry named only the S3 `username` and `password` file values as a way GroundX can be given static keys. That list was incomplete. `docs/eks-access-scoping.md` now says the settings limit a pod only when GroundX is given no static AWS keys at all: `username` and `password` are unset in the `file` values and in the `file` values inside `extract` (`src/groundx/templates/_helpers/app/extract.tpl:101-103`, rendered as `key` and `secret` at `src/groundx/templates/resources/extract-config-py.yaml:123-124`), and no AWS key variables are in the Secrets the pods load as environment variables: the `cluster` `secrets` list and, when file access is on, the Secret named by `fileAccess` `storageCredentialsSecretName` (`src/groundx/templates/_helpers/app/file-access.tpl:222-233`, loaded through `envFrom` at `src/groundx/templates/app/api.yaml:135-140`; `src/groundx/values.yaml:66-69` documents the AWS key variables). The doc does not state which credential source takes precedence.

The Non-Goal "Validating bucket and queue names in Terraform" and decision 2's "`app_irsa_s3_buckets` and `app_irsa_sqs_queues` have no validation block" no longer hold. Review found that a direct Terraform run with an entry such as `"*"` would render a wildcard IAM resource. Both variables now carry a validation, written as a conditional so `null` (the absent state) passes on Terraform 1.9.8: every entry must match `^[A-Za-z0-9._-]+$`, the same characters `setup-eks`'s `name-list` answer type allows. An empty list still passes. Two `expect_failures` runs in `terraform/aws/eks/tests/node_diagnostics.tftest.hcl` (`wildcard_bucket_name_is_rejected`, `wildcard_queue_name_is_rejected`) failed before the validation existed and pass with it, on Terraform 1.9.8 and 1.14.0.

Review fix round 3 added this rule to the specs: the named-buckets and named-queues requirements in `specs/eks-access-scoping/spec.md` (this change) and `openspec/specs/eks-access-scoping/spec.md` (the live spec) each now state the rule, with a scenario that rejects `"*"` and one that lets `null`, `[]` and plain names (including the FIFO queue name `jobs.fifo`) pass.

### 2026-11-25: several ranges in lockout recovery, and a dotted queue name in the tests (review fix round 4)

Decision 9's lockout recovery uses the EKS user guide's shorthand command. With commas inside the quoted `publicAccessCidrs` value, AWS CLI 2.35.15 sends the ranges as one string, not a list (evidence kept outside the repo under the workspace's `.sdd-state/GX-184/evidence/cidr-cli/`). `docs/eks-access-scoping.md` keeps the single-range shorthand command, says it takes one range only, and adds the JSON form of `--resources-vpc-config` for several ranges, citing the AWS CLI shorthand syntax page. The test run `empty_s3_with_named_queues_has_no_s3_statement` in `terraform/aws/eks/tests/node_diagnostics.tftest.hcl` now names `jobs.fifo` as well as `file-process`, so the spec's must-not-block queue scenario is covered by a committed run.

### 2026-11-25: correction to the round 4 entry on several ranges in lockout recovery (review fix round 5)

The round 4 entry overstated the shorthand behavior. Comma-separated ranges inside the shorthand's double quotes become one value only when those quotes reach the AWS CLI, for example when the whole value is single-quoted or passed through a shell variable. Typed at a bash or zsh prompt, the shell removes the double quotes and the CLI sends each range separately. The JSON form is shown because it sends each range separately in both cases. `docs/eks-access-scoping.md` now says to use the shorthand command for a single range and the JSON form, exactly as shown, to keep access for other ranges too, and makes no claim that the quoted shorthand fails. Evidence, kept outside the repo in the workspace's `.sdd-state/GX-184/evidence/harness/`: `lockout-cli-multi-range-shells.txt` (bash 5.3.15 and zsh 5.9, each with the quotes removed by the shell and with the quotes reaching the CLI) and `lockout-cli-serialization.txt` (the single-range shorthand, the JSON form and the unquoted multi-range shorthand).

### 2026-11-26: tag read on copied objects, rendered-policy test assertions, the setup-eks re-run warning and queue keys (review fix round 6)

This entry replaces the Open Questions line "`s3:GetObjectTagging` on copy: left out; the on-cluster document copy confirms." and decision 3's sentence that `s3:GetObjectTagging` is not added. The on-cluster test did not confirm it. In the follow-up copy probe on the throwaway cluster (the main probe of the same run records its identity as `assumed-role/eyelevel-s3-sqs-worker-irsa-gx184`; the follow-up file records no identity line), `CopyObject` of a tagged source with the default tagging directive was denied with `AccessDenied`; copying an untagged source, and copying the tagged source with `--tagging-directive REPLACE`, both worked. Evidence, kept outside the repo in the workspace's `.sdd-state/GX-184/cluster-test/spike-20261126-095052-29795/`: `probe-copy-followup.txt` and `probe-result.txt`. The `S3Objects` statement now also allows `s3:GetObjectTagging`, on object ARNs only. Hosted precedent: cashbot-go's dev extraction storage grants `s3:GetObjectTagging` alongside `s3:GetObject` (cashbot-go `openspec/changes/archive/2026-10-27-protect-hosted-file-access/dev-extraction-storage.md:42` at `6dfd8e3d4`). The tagged copy has not been re-run on a cluster with the added action.

Decision 6's mock-provider runs replace the rendered `s3_sqs_admin` policy document's `json` with a fixed value, and review found that the runs checked only `local.app_irsa_statements`: changing the document's dynamic statement to `s3:*` on `*` passed every run. The three runs that name buckets or queues now also assert the rendered `data.aws_iam_policy_document.s3_sqs_admin[0]` statements (Sid, effect, actions and resources), and the run naming both buckets and queues asserts that no statement allows `s3:*`, `sqs:*` or the resource `*`. With the same change made in a scratch copy, the earlier test file passed all 21 runs and the new one failed 3, on Terraform 1.9.8 and 1.14.0 (evidence in the workspace's `.sdd-state/GX-184/evidence/fix6/mutation-*.log`). The endpoint run still checks the local: the file overrides the EKS module, so an assertion can read only the outputs the override sets (a scratch run asserting `module.eyelevel_eks.cluster_endpoint_public_access_cidrs` failed with "Unsupported attribute" on both versions, `.sdd-state/GX-184/evidence/fix6/module-input-probe.log`), and the pinned module (v20.37.2) has no output carrying the public ranges, so the value that reaches the module's input cannot be asserted in this file.

Decision 5's existing-install confirmation and the doc's re-run paragraph understated the end state. Continuing replaces `env.tfvars` with the script's template, so the operator's own edits (for example `nodes`, `node_replicas`, `node_diagnostics`, `dns_observability`, `eks_kms_source_policy_documents`, `cluster_role_arns`, `ssh_key_name`) are replaced or removed, and the network and cluster folders are applied with `--auto-approve` (`bin/shared/util` `deploy`) without stopping for a plan review. The confirmation now says so and points an install with an edited `env.tfvars` to "Existing installs" in `docs/eks-access-scoping.md`; `docs/eks-access-scoping.md` says not to re-run `setup-eks` on such an install. The yes/stop behavior is unchanged. `bin/tests/setup-eks-access-test` checks the new lines in the declined scenario.

The round 2 entry's list of static AWS keys missed the queue credentials. cashbot-go's queue client uses static keys when `key` and `secret` are both set (cashbot-go `pkg/model/services/queue.go:30-40` at `6dfd8e3d4`), and the chart gives each topic its own `key` and `secret`, falling back to `stream.key` and `stream.secret` (`src/groundx/templates/_helpers/services/topics.tpl:27-29`). `docs/eks-access-scoping.md` now says to leave `key` and `secret` unset in `stream` and in each queue under `stream.topics`.

### 2026-11-26: the IAM policy and its attachment in the tests (review fix round 7)

A cross-model review found that the runs stopped one step short of what reaches AWS: they asserted the rendered policy document, but not that `aws_iam_policy.s3_sqs_admin` uses it or that the attachment names the GroundX role. Replacing the resource's `policy` with an empty policy, or the attachment's `role` with another name, passed all 21 runs. The file's override of the `s3_sqs_admin` document now sets a recognizable `json` value, and the run that names buckets and queues asserts that the policy resource carries exactly that value and that the attachment's `role` is `eyelevel-s3-sqs-worker-irsa`. With either change made in a scratch copy, the earlier test file passed all 21 runs and the new one failed 1, on Terraform 1.9.8 and 1.14.0 (`.sdd-state/GX-184/evidence/fix8/mutation-*.log` in the workspace). The attachment's `policy_arn` is not asserted. With `command = plan` on Terraform 1.9.8 the ARN is unknown even with `override_resource` setting it: a scratch run asserting it failed with "Unknown condition value" (`.sdd-state/GX-184/evidence/fix8/policy-arn-at-plan-tf1.9.8.log`). The 1.9.8 binary has no `override_during` setting, which would supply override values during plan. An apply run was not tried because the plan would include `null_resource.wait_for_eks`, whose `local-exec` provisioner runs `aws eks update-kubeconfig` (`eks.tf:498-506`), and whether `terraform test` skips that provisioner for a mocked provider was not checked. The saved real-plan evidence for tasks 3.1 to 3.4 shows the attachment referring to `aws_iam_policy.s3_sqs_admin[0]`.

### 2026-11-26: tests on the rendered policy for every state, and the README's SQS and access wording (review fix round 8)

The runs that name buckets or queues asserted both `local.app_irsa_statements` and the rendered `data.aws_iam_policy_document.s3_sqs_admin[0]` statements, while the two runs that keep full access asserted only the local. Every state is now asserted on the rendered statements, and the local checks are removed. With the scratch-copy changes used earlier, the new file fails on each: the document's dynamic statement set to `s3:*` on `*` fails 5 runs, an empty policy on the resource fails 1, and the absent-state `FullS3` actions narrowed to `s3:GetObject` fail 1, on Terraform 1.9.8 and 1.14.0 (`.sdd-state/GX-184/evidence/fix9/` in the workspace). `openspec/config.yaml`'s note on how the policy is tested now says the same.

`README.md`'s "Using AWS SQS" said to configure `stream.existing` and set `stream.serviceType` to `sqs`. The chart builds each queue from `stream.topics.<name>` (`type` and `url`, `src/groundx/templates/_helpers/services/topics.tpl`) and reads no `stream.serviceType` for queues; the section now shows the five topics as in `src/groundx/values/values.aws.services.yaml`, with `stream.region` and `stream.enabled: false`; the latter turns off `groundx.stream.create` (`stream.tpl`), so the GroundX pod gets no `wait-for-stream` startup container waiting for an in-cluster Kafka (`groundx.tpl` and `app/golang.yaml`), says a queue's name for `app_irsa_sqs_queues` is the last part of its `url`, and says the optional post-processing and large-file delivery topics (`stream.topics.postProcess`, `stream.topics.largeFile`), which default to Kafka (`topics.tpl`), need the same `type: sqs`, `url` and `region` when those workers are on. The "Limiting AWS access" paragraph now says the bucket and queue lists limit the AWS role GroundX pods use and the address list limits only the public endpoint; the private endpoint is unchanged.

`ARCHITECTURE_NOTES.md` (two places) and `AGENTS.md` described `stream.serviceType: sqs` the same way; they now say `stream` has no `serviceType` and that SQS is set per queue with `stream.topics.<name>.type: sqs`.
