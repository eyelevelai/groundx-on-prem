## ADDED Requirements

### Requirement: The operator-configured Kubernetes version reaches the EKS module as `cluster_version`
The `environment_internal` variable in `terraform/aws/variables.tf` SHALL carry an optional
Kubernetes-version key, and its value SHALL be passed to `module "eyelevel_eks".cluster_version`
in `terraform/aws/eks/eks.tf`. Validation MUST observe the value as received by the module
(the module's own `cluster_version` output), never only the input variable/local echoing itself.

Polarity: finalize success — the configured value must be the one that lands on the resource,
not merely a value the plan re-states.

#### Scenario: Configured version reaches the module
- **WHEN** `environment_internal`'s version key is set to a specific version string and the plan
  is evaluated (`terraform -chdir=terraform/aws/eks test`, `command = plan`, mocked AWS provider)
- **THEN** `module.eyelevel_eks`'s own `cluster_version` output equals that configured value —
  it is not left `null`, not left absent, and does not merely mirror `var.environment_internal`
  without reaching the module boundary

### Requirement: An unset version key leaves the module input `null`, reproducing today's behavior
The version key SHALL default to `null`. An operator's existing, unmodified `env.tfvars` (which
carries no version key) MUST produce a zero-diff plan against an already-created cluster: no
existing cluster's control plane or managed node groups are retargeted by adopting this change.

Polarity: reject before state — omitting the key must not introduce any implicit version value;
no override state may be created for existing clusters.

#### Scenario: Unset version key produces a null module input, not the declared default
- **WHEN** `environment_internal`'s version key is omitted (the default case)
- **THEN** `module.eyelevel_eks`'s `cluster_version` output is `null` — specifically **not**
  `1.35` (the declared-but-previously-unused default) and not any other value — so an existing
  cluster's plan shows zero diff on this attribute

### Requirement: `setup-eks` emits the declared default version for a not-yet-created cluster
When the target EKS cluster does not yet exist, `terraform/aws/setup-eks` SHALL write the
declared version (`1.35`) into the `env.tfvars` it generates, so a new install is explicit and
reviewable at `terraform plan` time.

Polarity: finalize success — a fresh install's generated config carries an explicit, reviewable
version value, not an implicit AWS-selected one.

#### Scenario: Fresh install generates the declared default
- **WHEN** `setup-eks` runs against a cluster name with no existing EKS cluster
- **THEN** the generated `env.tfvars` sets the version key to `1.35`

### Requirement: `setup-eks` emits the cluster's actual running version for an existing cluster
When the target EKS cluster already exists, `terraform/aws/setup-eks` SHALL look up the
cluster's actual running Kubernetes version (via the AWS EKS API) and write that value into the
generated `env.tfvars`, instead of the declared default. Re-running the generator against a live
cluster MUST NOT silently reintroduce a stale/lower version that could trigger a rejected
downgrade or an unintended managed-node-group rollout.

Polarity: reject before state — regenerating config for a live cluster must not create a
version-downgrade state; the written value must match what is already running.

#### Scenario: Existing cluster generates its own running version, not the stale default
- **WHEN** `setup-eks` runs against a cluster name that already has a running EKS cluster whose
  actual version differs from the declared default (`1.35`)
- **THEN** the generated `env.tfvars` sets the version key to the cluster's actual running
  version (as read via the AWS EKS API) and **not** to `1.35`

### Requirement: `terraform/aws/`'s supported status is documented consistently
`README.md` and `AGENTS.md` SHALL describe `terraform/aws/`'s supported status consistently with
each other and with its actual, currently-deployed state on this branch. Neither document may
describe the path as both "no longer supported" and, elsewhere, as actively maintaining existing
deployments.

#### Scenario: README and AGENTS.md agree on supported status
- **WHEN** `README.md`'s "Legacy Terraform Deployment" section and `AGENTS.md`'s Terraform
  description are read together
- **THEN** both describe the same supported status for `terraform/aws/` on this branch — neither
  contradicts the other, and neither claims retirement while the repo also documents live
  diagnostics/maintenance procedures for existing deployments on the same path

### Requirement: Documentation states AWS's version-selection behavior as "the AWS default version"
Documentation added or edited by this change SHALL describe AWS's unset-`cluster_version`
behavior using the wording "the AWS default version" (matching AWS's own `CreateCluster` API
reference), and SHALL NOT use "the latest version" — the two can differ.

#### Scenario: Wording avoids "latest version"
- **WHEN** any documentation string added by this change describes AWS's unset-`cluster_version`
  behavior
- **THEN** the string reads "the AWS default version" and contains no instance of "latest
  version" describing that same behavior

### Requirement: Documentation names the version's owner, bump process, and EKS upgrade/extended-support policy
Documentation SHALL name who owns the declared default version and bumps it, describe the
bump process tied to the EKS support calendar, and state AWS's EKS upgrade-support and
extended-support cost behavior explicitly.

#### Scenario: Owner, bump process, and upgrade policy are documented
- **WHEN** an operator or maintainer reads the added documentation for the version key
- **THEN** it names an owner (or ownership rule) for the declared default, describes when/how it
  is bumped relative to the EKS support calendar, and states the EKS extended-support cost policy

### Requirement: Documentation gives operators an existing-cluster adoption procedure
Documentation SHALL tell an operator adopting the version key on an already-existing cluster to:
read the cluster's actual running version before setting the key, that EKS does not support
control-plane downgrades, that the same value also drives managed node group AMI selection, and
to review `terraform plan` output before it is applied (since `bin/environment eks` auto-approves).

#### Scenario: Existing-cluster adoption note is present and complete
- **WHEN** an operator reads the documentation for opting into the version key on a cluster that
  already exists
- **THEN** it instructs reading the actual running version first, states that EKS rejects
  control-plane downgrades, states that the value also affects managed node group AMI selection,
  and instructs reviewing the plan before applying

### Requirement: An automated Terraform test proves the configured value reaches the EKS module
A new `terraform/aws/eks/tests/*.tftest.hcl` file SHALL assert, at `command = plan` under a
mocked AWS provider and without overriding `module.eyelevel_eks` wholesale, that the module's own
`cluster_version` output equals the configured value when the version key is set, and is `null`
when it is unset. The test SHALL be wired into CI in this change (a new
`.github/workflows/terraform-tests.yml`), so it cannot silently go dormant.

Polarity: finalize failure — a version that does not reach the module (the historical regression
this ticket documents) must fail the test, not pass it.

#### Scenario: Test fails on the historical regression shape
- **WHEN** the module receives no `cluster_version` (today's behavior, prior to this change's
  wiring fix)
- **THEN** the test's "key set" run block fails, because the module's `cluster_version` output
  does not equal the configured value — proving the test is non-vacuous

#### Scenario: Test runs in CI on every push/PR/release
- **WHEN** a commit is pushed, a pull request is opened, or a release is published
- **THEN** `.github/workflows/terraform-tests.yml` runs `terraform -chdir=terraform/aws/eks test`
  and its result gates the workflow
