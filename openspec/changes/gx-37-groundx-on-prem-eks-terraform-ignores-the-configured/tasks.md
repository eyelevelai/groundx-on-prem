## 1. Core wiring and plan-time proof (thin vertical slice)

**Note (design D3, revised 2026-09-17):** the proof is split into two independent checks because
`aws_eks_cluster.this[0].cluster_version` is Optional+Computed in the provider schema — Terraform's
mock provider reports it as unknown at plan time for a real module resource regardless of
configuration, so it cannot be asserted on directly. See `design.md`'s revised D3 section.

- [x] 1.1 Add `terraform/aws/eks/tests/cluster_version.tftest.hcl`: two `command = plan` run
      blocks under `mock_provider "aws" {}` (reusing the existing `irsa_*`/IAM policy document
      overrides from `node_diagnostics.tftest.hcl`, not overriding `module.eyelevel_eks`) that
      assert on the **variable/local's own resolved value** — never on any `module.eyelevel_eks`
      output — (a) `environment_internal.eks_version` set to a version string asserts the
      resolved `var.environment_internal.eks_version` (or the local it flows through) equals that
      value; (b) the key unset asserts it resolves to `null`. Written first as the RED baseline:
      both assertions fail against today's code (the variable does not yet carry this key in the
      expected shape).
  check: ([ -f terraform/aws/env.tfvars ] || cp terraform/aws/env.tfvars.example terraform/aws/env.tfvars) && terraform -chdir=terraform/aws/eks init -backend=false && terraform -chdir=terraform/aws/eks test -filter=tests/cluster_version.tftest.hcl
- [x] 1.2 Add a structural wiring check confirming `terraform/aws/eks/eks.tf`'s
      `module "eyelevel_eks"` block's `cluster_version` argument expression references
      `environment_internal.eks_version` in Terraform's parsed configuration — via
      `terraform show -json` on a real plan's
      `configuration.root_module.module_calls.eyelevel_eks.expressions.cluster_version.references`,
      or the source-line grep fallback if the JSON approach proves awkward to script reliably.
      Written first as RED: `eks.tf` does not yet set `cluster_version` at all, so the check must
      fail before task 1.3 wires it.
      **Implementation-time mechanism choice (empirically confirmed):** the JSON-reference-graph
      approach requires a real (non-mocked) `terraform plan` against `terraform/aws/eks`'s `aws`
      provider block, which validates credentials via `sts:GetCallerIdentity` unconditionally at
      provider-configure time (confirmed live: with no AWS credentials the plan fails on an IMDS
      timeout, and with a fake static key/secret it still fails, now with a `403
      InvalidClientTokenId` from a real STS call) — this environment has no AWS credentials, so
      that mechanism cannot run here regardless of `eks.tf`'s wiring. Using the pre-authorized
      source-line grep fallback instead, which needs no provider/credentials at all:
      `grep -E 'cluster_version\s*=\s*var\.environment_internal\.eks_version'
      terraform/aws/eks/eks.tf`.
  check: grep -E 'cluster_version\s*=\s*var\.environment_internal\.eks_version' terraform/aws/eks/eks.tf
- [x] 1.3 Change `environment_internal` in `terraform/aws/variables.tf` to
      `object({ eks_version = optional(string) })` with default `{}` (null-defaulting), and wire
      `cluster_version = var.environment_internal.eks_version` into `module "eyelevel_eks"` in
      `terraform/aws/eks/eks.tf`.
  check: ([ -f terraform/aws/env.tfvars ] || cp terraform/aws/env.tfvars.example terraform/aws/env.tfvars) && terraform -chdir=terraform/aws/eks init -backend=false && terraform -chdir=terraform/aws/eks test -filter=tests/cluster_version.tftest.hcl && grep -E 'cluster_version\s*=\s*var\.environment_internal\.eks_version' terraform/aws/eks/eks.tf

## 2. `env.tfvars.example` documents the new key

- [x] 2.1 Add `environment_internal = { eks_version = "1.35" }` to
      `terraform/aws/env.tfvars.example`, so a copied-fresh example is explicit for new installs.
  check: grep -q "environment_internal" terraform/aws/env.tfvars.example && grep -q "eks_version" terraform/aws/env.tfvars.example

## 3. `setup-eks` resolves the actual version for an existing cluster

- [x] 3.1 Add a `cluster_name` output to `terraform/aws/eks/outputs.tf`, mirroring the existing
      `cluster_endpoint` guard shape (`length(module.eyelevel_eks) > 0 ? ... : "(not created)"`).
  check: grep -q 'output "cluster_name"' terraform/aws/eks/outputs.tf
- [x] 3.2 Add `bin/tests/resolve-eks-version-test` with fake `terraform`/`aws` stubs on `PATH`
      (sibling of `bin/tests/fake-kubectl`), sourcing `bin/shared/util` and calling
      `resolve_eks_version` directly for the "existing cluster" case (fake `terraform output`
      returns a cluster name, fake `aws eks describe-cluster` returns a running version other
      than `1.35`) and the "not yet created" case (fake `terraform output` fails/empty). Written
      first as RED: `resolve_eks_version` does not exist yet.
  check: bash bin/tests/resolve-eks-version-test
- [x] 3.3 Add `resolve_eks_version()` to `bin/shared/util` (alongside `test_aws()` /
      `test_kubernetes_version()`): look up `terraform -chdir="$env_dir/eks" output -raw
      cluster_name`; if it names an existing cluster, run `aws eks describe-cluster --name
      <name> --query cluster.version --output text` and use that value; otherwise (or on any
      lookup failure) fall back to the declared default.
  check: bash bin/tests/resolve-eks-version-test
- [x] 3.4 In `terraform/aws/setup-eks`, call `eks_version=$(resolve_eks_version "$ENV_DIR"
      "1.35")` and add `environment_internal = { eks_version = "$eks_version" }` to both
      `env.tfvars` heredocs (the "testing EKS cluster configuration" block at ~L123-137 and its
      `$SEARCH`-gated repeat at ~L222-236).
  check: bash bin/tests/resolve-eks-version-test

## 4. CI wiring

- [x] 4.1 Add `.github/workflows/terraform-tests.yml`, a sibling of `helm-tests.yml` with the
      same trigger set (`push: ["**"]`, `pull_request`, `release`, `workflow_dispatch`), using
      `hashicorp/setup-terraform` pinned to `terraform_version: "1.7.0"`, then
      `cp -n terraform/aws/env.tfvars.example terraform/aws/env.tfvars`, then
      `terraform -chdir=terraform/aws/eks init -backend=false`, then
      `terraform -chdir=terraform/aws/eks test`.
  check: n/a — CI workflow file; exercised by the platform on push/PR, not locally runnable in this worktree

## 5. Documentation reconciliation

- [x] 5.1 Reconcile `README.md`'s "Legacy Terraform Deployment" section (L824-835) and
      `AGENTS.md`'s "legacy, deprecated" wording (lines 6, 11, 82) so both consistently describe
      `terraform/aws/` as an active, supported path for existing deployments on this branch — no
      remaining claim that the hybrid approach "is no longer supported" alongside documentation
      of live diagnostics/maintenance for existing deployments on the same path.
  check: ! grep -Eq "no longer supported" README.md
- [x] 5.2 Add a documentation section (`README.md` or a new `docs/eks-cluster-version.md`,
      matching the `docs/eks-node-diagnostics.md` precedent) that: names the version's owner
      (whoever owns `groundx-on-prem`) and bump process tied to the EKS support calendar; states
      the EKS upgrade-support and extended-support cost policy; states AWS's unset-version
      behavior as "the AWS default version" (never "the latest version"); and gives the
      existing-cluster adoption procedure — read the actual running version first
      (`aws eks describe-cluster --name <c> --query cluster.version`), EKS does not support
      control-plane downgrades, the value also drives managed node group AMI selection, and
      review `terraform -chdir=terraform/aws/eks plan` before `bin/environment eks` (which
      auto-approves).
  check: grep -Rq "AWS default version" README.md docs/ && ! grep -Rq "the latest version" README.md docs/

## Rollout order

1. **Level 1 (only level)**: groundx-on-prem — single repo, no cross-repo touchpoints.

## Database migrations (run manually)

None — this change touches only Terraform configuration, a Bash helper function, CI workflow
config, and documentation. No schema or seed data changes.

## Hand-off (driven by the hand-off gate after all repos archive)

- [ ] Push groundx-on-prem's feature branch — the hand-off gate prompts and pushes on
      confirmation.
      check: n/a — pipeline hand-off action performed by /sdd-feature's Step 12, not a repo-local
      verifiable check.
- [ ] Open a PR **against `0.2.7`**, not `main` (this feature's base branch override).
      check: n/a — pipeline hand-off action performed by /sdd-feature's Step 12, not a repo-local
      verifiable check.
- [ ] After the PR merges, return `repos/groundx-on-prem` to its declared base branch
      (`git -C repos/groundx-on-prem checkout main` per `repos.yml`; the *feature's* base was
      `0.2.7`, but the anchor clone's own tracked branch per `repos.yml` stays `main` — do not
      leave the anchor on `0.2.7`) and the root meta-repo to its declared branch.
      check: n/a — manual human action performed after PR merge, not a repo-local verifiable check.

## Deferred follow-ups (expand/contract)

None named by this change.
