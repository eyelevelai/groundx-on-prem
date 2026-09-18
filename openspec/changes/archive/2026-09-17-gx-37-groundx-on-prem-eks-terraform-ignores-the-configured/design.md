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

**D3 verification — REVISED 2026-09-17 (escalation resolved by the human).** The original plan
assumed a `terraform test` `command = plan` run under `mock_provider "aws" {}` could assert
directly on `module.eyelevel_eks[0].cluster_version` (the module's own output) and observe the
literal configured value at plan time, reasoning that an explicitly-set argument (unlike a
provider-computed one) keeps its configured value under mocking. **This was verified empirically
and found false for this module.** `aws_eks_cluster.this[0]` declares `cluster_version` in its
schema with both `Optional: true` and `Computed: true` (it is a version the provider can also
select/normalize, not a pure pass-through). Terraform's mock provider engine reports the resolved
value of any `Optional+Computed` attribute as `(known after apply)` — i.e. unknown — at plan time
for a real (non-overridden) module resource, **regardless of whether the config sets it**. This
was confirmed live against `terraform-aws-modules/eks/aws` v20.37.2 under this repo's own
`mock_provider "aws" {}`: both the "key set" and "key unset" run blocks show
`module.eyelevel_eks[0].cluster_version` as unknown at plan time, so an assertion against it
cannot distinguish the two cases — the single-assertion mechanism the plan specified is vacuous
for this module, not merely weak.

The escalation was resolved by the human by **splitting the proof into two independent, narrower
checks**, each of which is provably non-vacuous for the specific claim it makes:

1. **Value-resolution test (`.tftest.hcl`, `command = plan`).** Assert directly on
   `var.environment_internal.eks_version` / the local it resolves through — **not** on any
   resource or module output — for both cases: unset → `null`, set to a specific string → that
   exact string. A plain Terraform variable/local is never `Optional+Computed`; its resolved
   value is fully known at plan time regardless of provider mocking. This proves the *value
   computation* (D1's null-equivalence, the type change in `variables.tf`) is correct. It does
   **not** by itself prove the value reaches the module — that would repeat the exact vacuous
   claim just falsified above if the assertion target were a module output instead.
2. **Structural wiring check (new, non-`.tftest.hcl` mechanism).** Confirm — independently of any
   resolved resource value — that `terraform/aws/eks/eks.tf`'s `module "eyelevel_eks"` block's
   `cluster_version` argument expression actually **references**
   `var.environment_internal.eks_version` (or the local it resolves through). Terraform's parsed,
   unevaluated configuration reference graph describes *wiring*, not resolved state, so it does
   not suffer the Optional+Computed unknown-at-plan-time problem. Preferred mechanism: run
   `terraform -chdir=terraform/aws/eks plan -out=tfplan`, then
   `terraform -chdir=terraform/aws/eks show -json tfplan`, and inspect
   `.configuration.root_module.module_calls.eyelevel_eks.expressions.cluster_version.references`
   for an entry containing `environment_internal`. A plain source-line grep
   (`grep -E 'cluster_version\s*=\s*var\.environment_internal\.eks_version'
   terraform/aws/eks/eks.tf`) is an acceptable simpler fallback, chosen at implementation time if
   the JSON-reference-graph approach proves awkward to script reliably against this Terraform
   version's `show -json` output shape.

Together (1) proves the value is computed correctly and (2) proves that value is the one wired
into the module argument — covering AC #6 (the configured value reaches the module) without
requiring the disproportionate ~15-resource mock-data stack a full-module-output assertion would
have needed to work around the Optional+Computed limitation (rejected as disproportionate for this
thin-slice fix). Both checks remain independently RED-failing against today's unwired code: check
(1) fails because the variable doesn't yet exist in the expected shape; check (2) fails because
`eks.tf` does not yet reference `environment_internal.eks_version` in `cluster_version` at all.

The new value-resolution test file lives at `terraform/aws/eks/tests/cluster_version.tftest.hcl`,
a sibling of `node_diagnostics.tftest.hcl` that does not carry a file-level `override_module` on
`module.eyelevel_eks` (it may still reuse the `irsa_*` and IAM policy document overrides) — it
never asserts on the module's output, only on the variable/local's own value.

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
[ -f terraform/aws/env.tfvars ] || cp terraform/aws/env.tfvars.example terraform/aws/env.tfvars
terraform -chdir=terraform/aws/eks init -backend=false && \
terraform -chdir=terraform/aws/eks test -filter=tests/cluster_version.tftest.hcl
```
`init -backend=false` still performs the module-source fetch (network required for
`terraform-aws-modules/eks` 20.37.2) but skips remote state, matching the plan's distinction
between an infrastructure failure (init) and the intended RED assertion failure (test). The
existence check guards the `env.auto.tfvars` dangling-symlink precondition without touching a
tracked file (`env.tfvars` stays untracked, matching today's convention — `setup-eks` already
treats it as generated, disposable state). **Portability note (found during GREEN confirmation):**
the originally-specified `cp -n` is not portable — GNU `cp -n` exits 0 when skipping an existing
destination, but BSD/macOS `cp -n` exits 1, silently short-circuiting the `&&`-chained check on a
Mac with no output at all. `[ -f ... ] || cp ...` is portable across both.

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
cascade wording; D3's revised two-check wiring proof) are confirmed above.

**2026-09-17 — D3 escalation resolved by the human.** The apply-mode spawn empirically verified
(live, against the pinned module) that `aws_eks_cluster.this[0].cluster_version` is
`Optional+Computed` in the underlying provider schema, so Terraform's mock engine reports it as
unknown at plan time for a real (non-overridden) module resource regardless of whether the config
sets it — falsifying the plan's D3 assumption that a single module-output assertion would be
observable. The builder correctly escalated rather than weaken the test silently. Resolution: split
D3's proof into (1) a `.tftest.hcl` assertion on the variable/local's own resolved value (set vs.
unset — never Optional+Computed, fully known at plan time) and (2) a separate structural wiring
check on Terraform's parsed configuration reference graph (`terraform show -json`'s
`module_calls.eyelevel_eks.expressions.cluster_version.references`, or a source-line grep fallback)
confirming `eks.tf`'s `cluster_version` argument actually references
`environment_internal.eks_version`. See the revised D3 verification above for the full reasoning.

## Amendments

**2026-09-18 — review fix round 1: D1.6's existing-cluster detection was corrected; two risk
statements above were false.** All three automated reviewers found the same critical bug: the
originally-shipped `resolve_eks_version()` (see D1.6 above) detected an existing cluster by
reading the newly-added `terraform/aws/eks/outputs.tf` `cluster_name` output. That output does
not exist in any pre-change cluster's Terraform state, so on the very first run after adopting
this change, the existing-cluster branch was unreachable for every real existing cluster — the
lookup always fell through to the declared default and `setup-eks` auto-applied it with no
confirmation gate, which is exactly the unattended-downgrade risk this feature exists to prevent.

**Corrected mechanism.** `resolve_eks_version()` now reads `terraform -chdir="$env_dir/eks" show
-json` directly and searches the parsed state (`jq`, recursive descent over all resources at any
nesting depth) for an `aws_eks_cluster` resource's `name` — this exists in Terraform state for
*any* prior apply of this module (the underlying `terraform-aws-modules/eks/aws` module has always
created this resource), independent of whether the new `cluster_name` output is present. The
`cluster_name` output itself is left in place as a convenience for operators inspecting `terraform
output` after apply, but the safety-lookup path no longer depends on it.

**Fail loud, not open, on an unresolvable lookup.** The function now distinguishes three cases: (a)
no Terraform state at all, or state with no `aws_eks_cluster` resource → genuinely no existing
cluster, emit the declared default (safe); (b) an `aws_eks_cluster` resource is found but `aws eks
describe-cluster` cannot resolve its running version (bad credentials, missing IAM permission,
wrong region, throttling) → emit a `warn()` naming the failure and return non-zero, emitting no
version at all; `terraform/aws/setup-eks` now checks this exit code at both call sites and aborts
(`exit 1`) rather than writing any `env.tfvars`. Case (b) never silently falls back to the declared
default.

**The two risk statements below claiming otherwise are corrected, not deleted, per record
hygiene — do not treat the original "Risks / Trade-offs" section above as current:**
- "this reproduces exactly the pre-fix behavior for that one run, no worse than today" was false —
  the pre-fix behavior on a lookup failure was to write the declared default and let
  `bin/environment eks` auto-apply it unattended; that is the exact regression this change exists
  to prevent, not a neutral no-op. The corrected behavior aborts `setup-eks` before writing
  `env.tfvars` at all.
- "the printed terraform plan surfaces any diff before auto-apply" was false as a mitigation for a
  lookup failure — `bin/environment eks` calls `terraform apply --auto-approve` with no
  confirmation gate (documented accurately elsewhere in this same design and in README.md's
  existing-cluster adoption note), so a plan diff is never reviewed by a human before it applies.
  The corrected mitigation is refusing to proceed at all on an unresolvable lookup, not a plan
  review that does not exist in this unattended path.

**Single source of truth for the declared default (F7).** The literal `"1.35"` was previously
duplicated in three places (`terraform/aws/env.tfvars.example` and two `setup-eks` call sites).
`bin/shared/util` now also carries `declared_eks_version_default()`, which parses the
`environment_internal.eks_version` value out of `env.tfvars.example` at runtime; both `setup-eks`
call sites derive the default from it instead of hardcoding the literal. `env.tfvars.example`
remains the single authored source of the declared default value.

**Test coverage added.** `bin/tests/resolve-eks-version-test` gained a third scenario,
`existing_cluster_lookup_fails` (state shows an existing cluster, the AWS lookup fails), asserting
the corrected fail-loud behavior — non-zero exit, no version emitted on stdout, never the declared
default. `.github/workflows/terraform-tests.yml` gained three new steps: a structural check that
`eks.tf`'s `cluster_version` argument references `environment_internal.eks_version` (previously
only asserted by a local task check, never run in CI — a reviewer-found gap), a step running
`bin/tests/resolve-eks-version-test` (previously not wired into any CI workflow), and a step
running the new `bin/tests/setup-eks-wiring-test`, which statically asserts `setup-eks` itself
calls `resolve_eks_version`/`declared_eks_version_default` and writes their results into both
heredocs (F8 — task 3.4's original check exercised `resolve_eks_version` in isolation only, never
`setup-eks`'s own use of it).

**`cluster_version.tftest.hcl`'s "configured value" run block was removed, not kept alongside the
new CI structural check.** That run block set `environment_internal = { eks_version = "1.36" }`
in its own `variables` block and then asserted the value equaled `"1.36"` — tautological, since no
production code path could make it fail. Its intended job (proving the "set" case reaches the
module) is now covered by the CI structural-wiring step added above; the remaining
`unset_version_resolves_to_null` run block still proves the type/default-resolution half of D1
that the structural check does not cover.
