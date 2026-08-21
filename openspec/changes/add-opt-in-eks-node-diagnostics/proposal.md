## Why

Recurring production EKS nodes become unreachable while EC2 health remains
green, but existing telemetry has not preserved enough final host evidence to
establish the guest-level cause. The Terraform-managed cluster needs a simple,
explicitly enabled diagnostic path that improves node evidence without changing
GroundX application behavior or adding a new incident-processing service.

## What Changes

- Add one Terraform setting, `node_diagnostics.enabled`, defaulting to `false`.
- Preserve the current Terraform plan when the setting is omitted or `false`:
  no diagnostic add-on, host configuration, permissions, or Helm changes.
- When explicitly enabled, install a pinned, cluster-compatible EKS Node
  Monitoring Agent add-on through the existing `cluster_addons` map. Schedule
  its node agent only on the configured CPU-only and CPU-memory pools, and do
  not replace or duplicate the existing CloudWatch GPU monitoring.
- Use the agent's native node conditions, events, and `NodeDiagnostic` bundles.
  Provide one small, local-download operator command for one exact failed node.
  It atomically refuses an existing capture and cleans up only the exact
  `NodeDiagnostic` identity it created. Keep batch automation and S3 logic out
  of the command; the runbook may point to AWS's manual S3 procedure.
- Keep the existing CloudWatch Container Insights logs and metrics as supporting
  evidence. Do not add another alarm, collector, or log pipeline.
- Document the fallback when native collection cannot reach the node: preserve
  the incident identifiers, collect existing Kubernetes, CloudWatch, EC2, and
  Auto Scaling evidence, retrieve EC2 console output, and request separate
  approval before taking a root-volume snapshot. Prove the relevant fallback
  with an authorized canary that removes EKS API connectivity from a disposable
  non-production CPU node while preserving CloudWatch and EC2 connectivity.
- Keep automatic capture, Lambda, EventBridge, SSM documents, termination hooks,
  VPC Flow Logs, scheduled cleanup, batch capture automation, custom S3 upload
  logic, EKS node repair, application retry behavior, workload sizing, and
  GroundX Helm workloads outside this change.

## Capabilities

### New Capabilities

- `eks-node-diagnostics`: Terraform-managed, default-off AWS EKS node-health
  signals plus operator-triggered native diagnostic bundles.

### Modified Capabilities

None.

## Impact

- **Blast radius:** none while disabled. When enabled, the EKS Node Monitoring
  Agent runs only on the configured CPU-only and CPU-memory worker pools in the
  selected cluster. Existing CloudWatch GPU monitoring, GroundX application
  resources, and Helm values remain unchanged.
- **Affected environments:** only AWS EKS environments provisioned by the
  bundled Terraform and explicitly enabled. Non-AWS installs are unaffected.
- **Stateful impact:** no application-data change and no Terraform-managed
  diagnostic store. The command saves bundles locally. Manual S3 collection or
  a root snapshot remains a separate, explicit operation.
- **Rollout risk:** the enabled add-on consumes small per-node resources and is
  privileged so it can inspect host state. Canary its exact compatible version
  and verify its CPU-pool scheduling, absence from GPU pools, isolated-node
  behavior, and fallback evidence before production.
- **Rollforward:** create the implementation branch from refreshed
  `origin/0.2.7`, pin the currently applied EKS Terraform module version, pin a
  compatible Node Monitoring Agent version, verify the safe operator command
  and reachable and isolated-node evidence on a disposable cluster node, and
  submit the PR against `0.2.7`.
- **Rollback:** set `node_diagnostics.enabled` to `false` and apply a reviewed
  plan. This removes the add-on and stops new native captures. Previously saved
  bundles remain under their operator-selected storage and retention policy.
- **Cost:** the add-on's CPU and memory on the CPU-only and CPU-memory pools,
  plus any storage an operator explicitly chooses for a bundle or snapshot.
- **Open design questions:** none. The implementation must discover the target
  cluster's Kubernetes version, pin a compatible add-on version that supports
  the `NodeDiagnostic` `node` destination, and verify its supported scheduling
  configuration; failure to verify compatibility blocks rollout.
