# AWS infrastructure with Terraform

`terraform/aws/` is an optional path for provisioning AWS infrastructure (a VPC and/or an EKS
cluster) ahead of the Helm install in the [main README](../../README.md#helm-installation); see [Deployment](../../README.md#what-is-groundx-on-prem)
step 1. It is also the supported path for maintaining AWS infrastructure already provisioned
through it. As of November 4, 2025, the previous **hybrid terraform-helm approach to deploying the
GroundX application itself** was retired in favor of a pure Helm release; that change is about how
the application is installed onto a cluster, not about Terraform's role in provisioning the
cluster, which is unaffected and remains supported for both new and existing AWS installs.

## Accessing Legacy Scripts
If you would like to access the legacy terraform scripts, they can be pulled from [legacy-terraform-deployment](https://github.com/eyelevelai/groundx-on-prem/releases/tag/legacy-terraform-deployment).

## EKS CPU and monitoring cost controls

CPU-only nodes default to gp3 disks and one unavailable node per update. CloudWatch keeps enhanced Container Insights enabled and Application Signals disabled. See [EKS cost controls](../../docs/agents/eks-cost-controls.md) before applying these settings to an existing cluster.

## Optional EKS Node Diagnostics

AWS EKS deployments managed by the bundled Terraform (new or existing) can enable default-off
diagnostics with one setting. See [EKS Node Diagnostics](../../docs/eks-node-diagnostics.md).

## EKS Cluster Version Configuration

`terraform/aws/variables.tf`'s `environment_internal.eks_version` key controls the Kubernetes
version requested for a new EKS cluster (via `terraform/aws/eks/eks.tf`'s
`module "eyelevel_eks".cluster_version`). Leaving the key unset (the default) passes `null` to
the module, so AWS creates the cluster at the AWS default version rather than a version this repo
selects. See the [EKS `CreateCluster` API
reference](https://docs.aws.amazon.com/eks/latest/APIReference/API_CreateCluster.html) for what
"the AWS default version" means; it is not necessarily the newest version EKS offers.

**Owner and bump process.** The declared default in `terraform/aws/env.tfvars.example` (currently
`1.35`) is owned by whoever maintains `groundx-on-prem`. Bump it when the currently-declared
version approaches the end of its [AWS EKS standard support
window](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-version-support.html), so new
installs land on a version still inside standard support.

**What happens when standard support ends.** This module does not set an [EKS upgrade
policy](https://docs.aws.amazon.com/eks/latest/APIReference/API_UpgradePolicyRequest.html), so the
outcome depends on the policy the cluster ends up with (AWS's own default for newly created
clusters is `EXTENDED`; an existing cluster this Terraform now maintains may already carry a
different policy set outside this repo):

- **`EXTENDED`**: the cluster keeps running its current version past standard support, at an
  additional per-cluster hourly cost ([EKS pricing](https://aws.amazon.com/eks/pricing/)), until it
  reaches its extended-support end date.
- **`STANDARD`**: there is no paid extended-support period; AWS force-upgrades the cluster to the
  next supported version once standard support ends, whether or not that upgrade was planned.

Know which policy your cluster has (`aws eks describe-cluster --name <cluster> --query
cluster.upgradePolicy`) so you know which of these two outcomes to expect, and budget for it.

**Adopting the key on an existing cluster.** `setup-eks` writes the key automatically: it reads
Terraform state (`terraform show -json`) to find an existing cluster, then looks up that cluster's
actual running version via `aws eks describe-cluster`; the declared default is only used when
state shows no cluster at all. If a cluster is found in state but its running version cannot be
resolved (bad credentials, missing IAM permission, wrong region, throttling), `setup-eks` aborts
rather than silently falling back to the declared default and risking an unattended downgrade. A
normal re-run is safe, an unresolvable one stops instead of guessing. An operator hand-editing
`env.tfvars` for an existing cluster must instead:

1. Read the cluster's actual running version first: `aws eks describe-cluster --name <cluster>
   --query cluster.version --output text`. EKS does not support control-plane downgrades, so
   setting a lower version than what is running is rejected.
2. Know that this same value also drives every EKS-managed node group's AMI release selection
   (`groundx-on-prem`'s node groups don't override it, so they inherit the cluster's resolved
   version). Changing it can trigger a managed-node-group rollout, not just a control-plane
   change.
3. Review `terraform -chdir=terraform/aws/eks plan` before applying. `bin/environment eks` calls
   `terraform apply --auto-approve` with no confirmation gate, so the plan output is the only
   review point before a version change takes effect.
