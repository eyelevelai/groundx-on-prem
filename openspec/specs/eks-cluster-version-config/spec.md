# eks-cluster-version-config Specification

## Purpose
TBD - created by archiving change gx-37-groundx-on-prem-eks-terraform-ignores-the-configured. Update Purpose after archive.
## Requirements
### Requirement: The operator-configured Kubernetes version reaches the EKS module as `cluster_version`
The `environment_internal` variable in `terraform/aws/variables.tf` SHALL carry an optional
Kubernetes-version key, and its value SHALL be passed to `module "eyelevel_eks".cluster_version`
in `terraform/aws/eks/eks.tf`. This wiring is verified by code review; no automated check asserts
it (see the testing requirement below). A test that only asserts a variable equals the value it
was given proves nothing about this wiring, because Terraform's mock provider reports the
module's resulting resource attribute as unknown at plan time (see `design.md` D3).

Polarity: finalize success — the configured value must be the one that lands on the resource,
not merely a value the plan re-states.

#### Scenario: The module call passes the configured value
- **WHEN** `terraform/aws/eks/eks.tf`'s `module "eyelevel_eks"` block is reviewed
- **THEN** its `cluster_version` argument is `var.environment_internal.eks_version`

### Requirement: An unset version key leaves the module input `null`, reproducing today's behavior
The version key SHALL default to `null`. An operator's existing, unmodified `env.tfvars` (which
carries no version key) MUST produce a zero-diff plan against an already-created cluster: no
existing cluster's control plane or managed node groups are retargeted by adopting this change.

Polarity: reject before state — omitting the key must not introduce any implicit version value;
no override state may be created for existing clusters.

#### Scenario: Unset version key resolves to null, not the declared default
- **WHEN** `environment_internal`'s version key is omitted (the default case) and the plan is
  evaluated (`terraform -chdir=terraform/aws/eks test`, `command = plan`, mocked AWS provider)
- **THEN** the resolved value of `var.environment_internal.eks_version` (or the local it flows
  through) is `null` — specifically **not** `1.35` (the declared-but-previously-unused default)
  and not any other value — so an existing cluster's plan shows zero diff on this attribute

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
each other and with its actual, currently-deployed state on this branch: an optional path for
provisioning AWS infrastructure (a VPC and/or EKS cluster) ahead of the Helm install, and the
supported path for maintaining AWS infrastructure already provisioned through it. Neither document
may claim this path is retired, or scope it to existing deployments only — the November 4, 2025
migration retired the previous hybrid terraform-helm approach to deploying the *application* onto
the cluster (now a pure Helm release), not Terraform's role in provisioning or maintaining the
underlying AWS infrastructure.

#### Scenario: README and AGENTS.md agree on supported status
- **WHEN** `README.md`'s "Terraform Deployment (terraform/aws/)" section and `AGENTS.md`'s
  Terraform description are read together
- **THEN** both describe `terraform/aws/` the same way: optional for provisioning new AWS
  infrastructure and supported for maintaining existing AWS infrastructure it created — neither
  contradicts the other, neither claims retirement, and neither scopes the path to existing
  deployments only

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
bump process tied to the EKS support calendar, and state both outcomes of AWS's EKS upgrade
policy at the end of standard support (`EXTENDED`: paid extended support at an additional
per-cluster hourly cost; `STANDARD`: a forced upgrade to the next supported version, with no
extended-support period) — since this module leaves the policy unset and does not itself
determine which outcome a given cluster gets.

#### Scenario: Owner, bump process, and upgrade policy are documented
- **WHEN** an operator or maintainer reads the added documentation for the version key
- **THEN** it names an owner (or ownership rule) for the declared default, describes when/how it
  is bumped relative to the EKS support calendar, and states both the `EXTENDED` (paid,
  cost-bearing) and `STANDARD` (forced upgrade) outcomes of AWS's upgrade policy

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

### Requirement: Tests guard only the logic whose regression would harm a live cluster
Tests added for this capability SHALL cover critical logic only, SHALL extend existing test files
where one already covers the area, and SHALL NOT assert that a variable equals the value it was
given. No dedicated CI workflow is added: this Terraform path is internal and unsupported for
customers, and the issue is rated Medium.

The guarded logic is:
- An unset version key resolves to `null`, so an existing `env.tfvars` produces a zero-diff plan
  (`terraform/aws/eks/tests/node_diagnostics.tftest.hcl`, `unset_version_resolves_to_null`).
- `resolve_eks_version` and `resolve_setup_eks_version` never emit a guessed version when an
  existing cluster is found but its running version cannot be read, and pass the operator-selected
  region through (`bin/tests/resolve-eks-version-test`).

Polarity: reject before state — a regression that lets `setup-eks` write a guessed or lower
version for a live cluster must fail the resolver tests.

#### Scenario: Lookup failure for an existing cluster never yields a version
- **WHEN** Terraform state shows an existing cluster and `aws eks describe-cluster` fails
- **THEN** `resolve_eks_version` and `resolve_setup_eks_version` exit non-zero and print nothing,
  never the declared default

#### Scenario: Region is passed to the AWS lookup
- **WHEN** a region is supplied
- **THEN** the `aws eks describe-cluster` call carries `--region <region>`; with no region, it
  carries no `--region` flag
