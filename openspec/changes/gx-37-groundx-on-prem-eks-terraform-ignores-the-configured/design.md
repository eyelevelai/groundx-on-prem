## Goals / Non-Goals

**Goals:**
- Wire `environment_internal`'s Kubernetes-version key through to `module.eyelevel_eks.cluster_version`
  with zero blast radius for existing, already-created clusters (D1).
- Make `terraform/aws/setup-eks` generate an `env.tfvars` that reflects reality for both a
  not-yet-created cluster (declared default) and an already-existing one (its actual running
  version), so re-running the generator cannot reintroduce a downgrade (D1.6).
- Prove the wiring with a `terraform test` assertion on the module's own output, not the input
  variable echoing itself, and wire that test into CI (D3, D4).
- Reconcile `README.md`/`AGENTS.md` on `terraform/aws/`'s supported status, and document the
  version's owner, bump process, EKS upgrade/extended-support policy, and the existing-cluster
  adoption procedure (D1.4, D5).

**Non-Goals:**
- No bump to the declared default value (`1.35`) — a separate ticket (D1.3).
- No re-pin of the EKS module version constraint — `0.2.7` already pins `20.37.2` with no loose
  constraint (Assumption 1); no code change needed for that acceptance criterion.
- No change to `bin/shared/util:test_kubernetes_version()` — it already rejects equality and this
  fix does not route through it (Assumption 3).
- No empirical proof that Terraform will not propose a correction after an AWS-initiated upgrade —
  no live cluster is available to this pipeline run; documented as expected-but-unverified (D5).

## Decisions

All five plan decisions (D1, D1.6, D2, D3, D4, D5) are binding, recorded in the workspace-level
`openspec/changes/gx-37-groundx-on-prem-eks-terraform-ignores-the-configured/design.md` (approved
at the plan gate). This section records the code-grounding verification the plan handed to the
builder, plus the concrete implementation shape.

**D1 verification — `cluster_version = null` is equivalent to omitting it.** Confirmed in the
pinned module source (`terraform-aws-modules/eks/aws` v20.37.2): `variables.tf` declares
`variable "cluster_version" { type = string; default = null }`, and `main.tf`'s
`resource "aws_eks_cluster" "this"` assigns `version = var.cluster_version` directly — no local
transform, no `coalesce`, no wrapping. Passing `null` explicitly and omitting the argument produce
the identical resolved value. The type change in `terraform/aws/variables.tf` is therefore:
`environment_internal = object({ eks_version = optional(string) })`, variable default `{}` — an
object whose only attribute is optional resolves its own default to `null` with no top-level
default value needed beyond `{}`.

**D1(iv) verification — node-group AMI cascade wording.** Confirmed in the same module's
`node_groups.tf`: each EKS-managed node group's own `cluster_version` resolves via
`try(each.value.cluster_version, var.eks_managed_node_group_defaults.cluster_version,
time_sleep.this[0].triggers["cluster_version"])`, where that trigger is
`aws_eks_cluster.this[0].version` — the cluster's own resolved version. `groundx-on-prem`'s
`eks_managed_node_group_defaults` (in `eks.tf`) does not set `cluster_version`, so every managed
node group inherits the cluster's resolved version and its AMI release selection follows it. The
existing-cluster documentation note must state this precisely: setting the key changes not only
the control plane target but every managed node group's AMI selection.

**D3 verification — the strong test mechanism is expressible; no escalation.** Confirmed in the
same module's `outputs.tf`: `output "cluster_version" { value = try(aws_eks_cluster.this[0].version,
null) }`. Because `aws_eks_cluster.this[0].version = var.cluster_version` is a direct
pass-through argument (not a provider-computed-only attribute), a `terraform test` `command = plan`
run under `mock_provider "aws" {}` resolves this attribute to the literal configured value — mocked
providers only synthesize values for attributes that are computed and *not* set in configuration;
an explicitly-configured argument (including an explicit `null`) keeps its configured value at plan
time. Both the "key set" and "key unset" run blocks are therefore observable at plan time on
`module.eyelevel_eks[0].cluster_version` — the escalation trigger in the plan's D3.4 does not fire.
The new test file lives at `terraform/aws/eks/tests/cluster_version.tftest.hcl`, a sibling of
`node_diagnostics.tftest.hcl` that does not carry a file-level `override_module` on
`module.eyelevel_eks` (it may still reuse the `irsa_*` and IAM policy document overrides).

**D1.6 verification — `setup-eks`'s existing-cluster lookup mechanism.** `terraform/aws/setup-eks`
has no pre-existing `aws eks describe-cluster` call to reuse (only `bin/shared/util:test_aws()`'s
connectivity check, `aws eks list-clusters`). The cluster's actual name is not knowable ahead of
creation — `terraform/aws/common.tf`'s `local.cluster_name = "${var.cluster.prefix}_
${random_string.name_suffix.result}"` includes a random suffix chosen at first apply and persisted
only in Terraform state. `terraform/aws/eks/outputs.tf` does not currently expose the cluster name.
Decision: add one output, `cluster_name`, alongside the existing `cluster_endpoint` output (same
`length(module.eyelevel_eks) > 0 ? ... : "(not created)"` guard shape already used there). `setup-eks`
then determines existence and identity from local Terraform state, which is exactly the context it
already runs in (it calls `terraform -chdir="$ENV_DIR/eks" output -raw <name>` for `storage_driver`
et al. immediately after apply, in the same working directory a re-run reads before generating a
fresh `env.tfvars`):
```
existing_cluster_name=$(terraform -chdir="$ENV_DIR/eks" output -raw cluster_name 2>/dev/null)
if [[ -n "$existing_cluster_name" && "$existing_cluster_name" != "(not created)" ]]; then
  eks_version=$(aws eks describe-cluster --name "$existing_cluster_name" \
    --query 'cluster.version' --output text 2>/dev/null)
fi
eks_version="${eks_version:-1.35}"
```
This reuses `test_aws`'s already-established AWS CLI context and requires no new IAM permission
class beyond `eks:DescribeCluster`, which is a read-only sibling of the `eks:ListClusters` call
`test_aws()` already makes. No escalation is needed — a feasible in-context lookup exists.

**D1.6 testability — extract a sourced function, following the repo's own precedent.**
`terraform/aws/setup-eks` is an interactive script (`prompt_menu`/`prompt_text`), so driving it
end-to-end in a test would require faking every prompt. `bin/tests/eks-node-logs-test` +
`bin/tests/fake-kubectl` already establish this repo's pattern for testing a `bin/` script: a
fake binary stub placed first on `PATH`, invoked directly, asserting on its logged calls and
output. The version-resolution logic is extracted into a small sourced function,
`resolve_eks_version()`, in `bin/shared/util` (alongside the existing `test_aws()` /
`test_kubernetes_version()` helpers), callable and testable independently of the interactive
script:
```
resolve_eks_version() {
  local env_dir="$1" declared_default="$2"
  local existing_cluster_name running_version
  existing_cluster_name=$(terraform -chdir="$env_dir/eks" output -raw cluster_name 2>/dev/null)
  if [[ -n "$existing_cluster_name" && "$existing_cluster_name" != "(not created)" ]]; then
    running_version=$(aws eks describe-cluster --name "$existing_cluster_name" \
      --query 'cluster.version' --output text 2>/dev/null)
    if [[ -n "$running_version" && "$running_version" != "None" ]]; then
      echo "$running_version"
      return 0
    fi
  fi
  echo "$declared_default"
}
```
`setup-eks` calls `eks_version=$(resolve_eks_version "$ENV_DIR" "1.35")` and writes
`environment_internal = { eks_version = "$eks_version" }` into both `env.tfvars` heredocs
(the "testing EKS cluster configuration" block and its `$SEARCH`-gated repeat). A new
`bin/tests/resolve-eks-version-test`, with fake `terraform`/`aws` stubs on `PATH` (sibling of
`fake-kubectl`), sources `bin/shared/util` and calls `resolve_eks_version` directly for both the
"existing cluster" and "not yet created" cases — no interactive prompts, no real AWS/Terraform
calls.

**D2, D4, D5 — no additional code-grounding required beyond the plan.** D2 (no third
`env.tfvars.example` artifact — `terraform/aws/env.tfvars.example` is the only one, plus
`setup-eks`'s generated file), D4 (CI workflow shape and the `terraform_version: "1.7.0"` pin), and
D5 (documentation wording constraint and the expected-but-unverified drift framing) are implemented
exactly as decided in the workspace-level design.md; see that document for the full rationale.

**RED-baseline check command (both preconditions handled in the command itself, per the plan):**
```
cp -n terraform/aws/env.tfvars.example terraform/aws/env.tfvars
terraform -chdir=terraform/aws/eks init -backend=false && \
terraform -chdir=terraform/aws/eks test -filter=tests/cluster_version.tftest.hcl
```
`init -backend=false` still performs the module-source fetch (network required for
`terraform-aws-modules/eks` 20.37.2) but skips remote state, matching the plan's distinction
between an infrastructure failure (init) and the intended RED assertion failure (test). The
`cp -n` guards the `env.auto.tfvars` dangling-symlink precondition without touching a tracked file
(`env.tfvars` stays untracked, matching today's convention — `setup-eks` already treats it as
generated, disposable state).

## Risks / Trade-offs

- [An operator with a pre-existing `env.tfvars` that already (accidentally) sets
  `environment_internal.eks_version` to something other than the cluster's actual version] →
  Mitigation: documented explicitly in the existing-cluster adoption note — read the real running
  version first; this change does not and cannot detect a manually-authored `env.tfvars` drift.
- [`setup-eks`'s new `aws eks describe-cluster` lookup silently fails (permissions, throttling) and
  falls back to `1.35`] → Mitigation: this reproduces exactly the pre-fix behavior for that one run
  (no worse than today), and the printed `terraform plan` (still required before `bin/environment
  eks` applies) surfaces any resulting diff for human review before auto-apply.
- [CI's `terraform test` requires network access to fetch the pinned module] → Mitigation: this is
  the existing `terraform init` dependency for this module on every environment already; not a new
  requirement introduced by this change.

## Migration Plan

No migration — this is additive Terraform variable + wiring + docs + CI. Existing clusters see a
zero-diff plan (D1); rollout to new clusters is a normal `terraform plan`/`apply` through the
existing `bin/environment eks` path. Rollback removes the wiring and the new variable; an operator
who already added the key to their `env.tfvars` after a revert would see it become an unused key
again (documented in `proposal.md`'s Rollback/rollforward section) rather than an error.

## Open Questions

None — all decisions were resolved at the plan gate (D1, D1.6, D2, D3, D4, D5) and the two
design-phase verifications the plan handed to the builder (D1's null-equivalence and node-group
cascade wording; D3's plan-time observability) are confirmed in the pinned module source above.
