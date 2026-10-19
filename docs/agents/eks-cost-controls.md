# EKS CPU and monitoring cost controls

The AWS Terraform defaults CPU-only root disks to gp3, 3000 IOPS, and 128 MiB/s. Their default size remains 30 GiB, encrypted, and deleted when the instance terminates. Explicit `nodes.node_groups.cpu_only_nodes.ebs` settings still take precedence. CPU-memory and GPU disk defaults remain unchanged.

The CPU-only node group sets `max_unavailable = 1`. Applying a root disk change through Terraform updates the managed launch template and can replace all nodes in that group. It does not modify existing attached disks in place. Creating a manual template version alone does not change which version EKS uses, and this configuration does not hard-code a manual version number.

CloudWatch configuration explicitly disables Application Signals auto-monitoring, automatic application restarts, and agent signal collection. Enhanced Container Insights and container logs remain enabled. Enabling or disabling `dns_observability` only adds or removes the dedicated CoreDNS collector. Disabling auto-monitoring does not remove existing application instrumentation annotations; previously instrumented applications require a separate reviewed cleanup and rollout.

## Validation and deployment

Run `terraform -chdir=terraform/aws/eks validate` and `terraform -chdir=terraform/aws/eks test -filter=tests/node_diagnostics.tftest.hcl` from an initialized checkout. Tests use mock providers and do not apply AWS changes.

For an existing installation, use its current Terraform state and input files. Do not initialize a new production state. Confirm the account, region, cluster, and actual disk overrides before reviewing a saved plan. Stop on cluster replacement or version changes, other node-group updates, or changes to stateful services. Retain the existing add-on version and DNS collection setting. Do not apply an unreviewed full-stack plan.

Schedule the CPU rollout during quiet maintenance, after current document-processing and workspace jobs finish. Use the standard EKS strategy that starts replacement capacity before retiring old nodes, without forced eviction. A one-node limit does not guarantee uninterrupted service: singleton workloads can pause while moving, and workers can exceed the EKS drain timeout. Temporary additional instances incur normal charges. Verify ingest, extraction, search, and Studio after the rollout.

Rolling back disk settings through Terraform can require another node replacement. Keep the cost configuration active when reverting an unrelated DNS setting. No production apply is implied by merging the source change.
