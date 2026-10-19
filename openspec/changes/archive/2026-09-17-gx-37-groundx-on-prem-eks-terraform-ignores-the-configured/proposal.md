## Why

`terraform/aws/variables.tf` declares `environment_internal.eks_version` (currently `1.35`), but
`module "eyelevel_eks"` (`terraform/aws/eks/eks.tf`) never receives it as `cluster_version`. AWS
therefore creates each new cluster at the AWS default version rather than the value an operator
sees in `env.tfvars`. The declared value has been bumped four times since it stopped reaching
anything, so `terraform plan` cannot show which Kubernetes version a new cluster will actually get,
and that choice cannot be reviewed before creation.

`terraform/aws/` is also documented inconsistently: `README.md`'s "Legacy Terraform Deployment"
section says the hybrid approach "is no longer supported" while, a few lines later, describing
diagnostics for "existing AWS EKS deployments still managed by the bundled Terraform," and
`AGENTS.md` separately calls the path "legacy, deprecated." The controlling authority for this
ticket (assignee instruction, the Linear comment thread, and groundx-on-prem PR #103) confirms
`terraform/aws/` on branch `0.2.7` is an active, currently-deployed path with real existing
clusters, so the fix is a real wiring change, not a documentation-only cleanup, and the documented
status must say so consistently.

## What Changes

- Add an optional, null-defaulting Kubernetes-version key to the `environment_internal` Terraform
  variable and wire it through to `module "eyelevel_eks".cluster_version`. The default stays
  `null`, so an operator's existing, unmodified `env.tfvars` (which carries no version key today)
  produces a zero-diff plan against an already-created cluster: adopting this change retargets no
  existing cluster.
- `terraform/aws/setup-eks` emits the version key populated in the `env.tfvars` it generates: the
  declared value (`1.35`) for a cluster that does not yet exist, or the target cluster's actual
  running version (looked up via the AWS EKS API) when one already exists, so re-running the
  generator against a live cluster cannot silently reintroduce a downgrade.
- `terraform/aws/env.tfvars.example` documents the new key.
- A new `terraform/aws/eks/tests/*.tftest.hcl` file asserts, at plan time against a mocked AWS
  provider, that the module receives the configured value when the key is set and receives `null`
  when it is unset, observed on the module's own output rather than on the input variable echoing
  itself.
- A new `.github/workflows/terraform-tests.yml` runs that test in CI, pinned to
  `terraform_version: "1.7.0"`.
- `README.md` and `AGENTS.md` are reconciled to describe `terraform/aws/`'s supported status
  consistently, and to document: the version key's owner and bump process, the EKS upgrade support
  and extended-support cost policy, and the steps an operator must follow to adopt the key on an
  existing cluster without triggering a control-plane downgrade or an unintended node-group
  rollout.
- Documentation added by this change describes AWS's version-selection behavior as "the AWS
  default version," the wording AWS's own `CreateCluster` API reference uses, not "the latest
  version": the two can differ.
- No change to the declared version value (`1.35`) and no change to the EKS module's version pin
  (`20.37.2`, already an exact pin on `0.2.7`): the loose `~> 20.0` constraint named in the ticket's
  evidence is a `main`-branch fact, not present on `0.2.7`.

## Capabilities

### New Capabilities
- `eks-cluster-version-config`: the operator-configured Kubernetes version reaching
  `module.eyelevel_eks.cluster_version` (or remaining `null` when unset), the `setup-eks`
  generation behavior for existing vs. not-yet-created clusters, and the documented supported
  status, owner, bump process, and upgrade policy for `terraform/aws/`.

### Modified Capabilities
None. No existing `openspec/specs/` capability covers `terraform/aws/`'s EKS version surface.

## Impact

Affected code: `terraform/aws/variables.tf`, `terraform/aws/eks/eks.tf`,
`terraform/aws/eks/common.tf` (if the value is resolved through a local),
`terraform/aws/env.tfvars.example`, `terraform/aws/setup-eks`, a new
`terraform/aws/eks/tests/*.tftest.hcl`, a new `.github/workflows/terraform-tests.yml`,
`README.md`, `AGENTS.md`, and a docs addition for the owner and bump-process and upgrade-policy
acceptance criteria.

Blast radius: `terraform/aws/` is applied through `bin/environment eks` calling
`bin/shared/util:deploy()`, which runs `terraform apply --auto-approve` with no confirmation gate.
Decision D1 (recorded in `design.md`) exists specifically to keep this change's blast radius at
zero for existing clusters: the new variable defaults to `null`, reproducing today's exact
behavior, so an operator who does not touch their `env.tfvars` sees no plan diff. Only an operator
who explicitly opts into the new key on an existing cluster is affected, and the documentation this
change adds tells them to read the cluster's actual running version first, because EKS does not
support control-plane downgrades and the same value also drives managed node group AMI selection.
New-cluster creation becomes explicit and reviewable, since the `setup-eks`-generated `env.tfvars`
shows the version that will be requested, meeting the ticket's acceptance criteria.

Environments: this repo's Terraform tooling has no named dev/staging/prod distinction;
`terraform/aws/` is parameterized per operator-supplied `env.tfvars`, not per named environment.
The rollout risk described above applies uniformly to any environment an operator runs
`terraform/aws/setup-eks` or `bin/environment eks` against.

Stateful-resource impact: none from this change alone under default (`null`) behavior. An operator
who opts into setting the version on an existing cluster is changing an EKS control plane and its
managed node groups; the documentation this change adds is the mitigation for that
operator-initiated risk, not a risk this change introduces on its own.

Rollback/rollforward: reverting this change removes the `cluster_version` wiring and the new
`environment_internal` key. An operator who kept an `env.tfvars` with the new key after a revert
would need to remove that key or accept it becoming unused again before running `terraform plan`.
No state migration is required in either direction.

Open design questions: none. The plan decisions (D1, D1.6, D2, D3, D4, D5) recorded in the approved
cross-service proposal resolve the blast-radius, test-strength, CI-wiring, and documentation-wording
questions that would otherwise need brainstorming here.
