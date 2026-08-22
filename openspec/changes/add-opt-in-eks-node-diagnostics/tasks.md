## 1. Establish Safe Terraform Baseline

- [x] 1.1 Fetch the remote, create the implementation branch from
  `origin/0.2.7`, and record and verify the branch point before changing files.
- [x] 1.2 Identify the exact EKS module version used by the production
  Terraform workspace and pin it; stop if it cannot be established.
- [x] 1.3 Add the typed `node_diagnostics.enabled` input with default `false`
  and document the single-value enablement in `env.tfvars.example`.
- [x] 1.4 Prove omitted and explicit-false inputs leave the existing
  `cluster_addons` map and Terraform plan unchanged.

## 2. Add The Managed Node Monitoring Agent

- [x] 2.1 Identify the target Kubernetes version, query supported
  `eks-node-monitoring-agent` versions and configuration, and pin one exact
  version that supports the `NodeDiagnostic` `node` destination introduced in
  `v1.6.1-eksbuild.1`.
- [x] 2.2 Configure node-agent affinity from `local.cpu_only_label` and
  `local.cpu_memory_label`. Disable the add-on's NVIDIA monitor and use supported
  scheduling configuration so its DCGM component has no eligible nodes, without
  changing the existing CloudWatch GPU monitoring.
- [x] 2.3 Conditionally merge the pinned add-on into the existing
  `cluster_addons` map without enabling EKS node repair or adding new AWS
  permissions.
- [x] 2.4 Record the verified managed-add-on scheduling, tolerations,
  privileges, requests, and limits. Verify its pods run on both configured CPU
  pools and not on GPU pools, while existing CloudWatch GPU monitoring remains.

## 3. Document The Operator Capture Path

- [x] 3.1 Add and document one small repo-owned, exact-node operator command over
  the native `NodeDiagnostic` API. Download the bundle locally; do not implement
  batch or S3 upload behavior.
- [x] 3.2 Use create-only semantics, record the created resource UID and
  generation, and use the UID and latest resource version as cleanup
  preconditions. Leave a pre-existing, concurrent, replaced, or edited resource
  untouched.
- [x] 3.3 Add focused command tests with a stubbed `kubectl` for successful local
  capture, create conflict, interruption, same-name replacement, and in-place
  update during capture, download, or cleanup. Verify status and output belong
  to the unchanged created generation and only that resource can be deleted.
- [x] 3.4 Document AWS's manual S3 procedure only as a separate option using an
  existing approved bucket and retention policy.
- [x] 3.5 Document UTC correlation across the bundle, node name, instance ID,
  Kubernetes node and pod state, recent events, existing CloudWatch logs and
  metrics, EC2 status, Auto Scaling activity, and EC2 console output.
- [x] 3.6 Document failed native collection plainly. Keep any root-volume
  snapshot as a separate, explicitly approved incident action; do not automate
  alarms, capture, termination delay, snapshot creation, or deletion.
- [x] 3.7 Document that bundles are sensitive operational evidence and must not
  be committed or attached to tickets without review.

## 4. Validate The Smallest Implementation

- [x] 4.1 Initialize and validate the EKS stack without modifying remote state,
  format-check the new Terraform test, run shell syntax and safety tests, and
  run `git diff --check`. Do not reformat the nine pre-existing Terraform files
  that fail the recursive formatting check on `0.2.7`.
- [ ] 4.2 Review an omitted and disabled plan against current state and prove
  there is no diagnostic or Helm change.
- [ ] 4.3 Review an enabled non-production plan and prove it contains only the
  exact EKS module pin, input, and managed add-on changes.
- [x] 4.4 Run the focused operator-command tests and prove create conflicts,
  interruption, same-name replacement, and in-place updates cannot accept
  another capture's status or output or delete a resource the command no longer
  owns unchanged.
- [x] 4.5 With separate authorization, canary the exact add-on version in a
  disposable non-production cluster. Verify node conditions and events, native
  bundle collection, refusal to alter a pre-existing capture, owned cleanup,
  scheduling on both CPU pools and nowhere else, resource use, unchanged
  CloudWatch GPU monitoring, and disable behavior.
- [x] 4.6 Inspect a reachable bundle for the expected kernel, memory, storage,
  container-runtime, and networking evidence sources. Stop and revise the plan
  if required sources are absent.
- [x] 4.7 With separate authorization, remove EKS API connectivity from a
  disposable non-production CPU node while preserving CloudWatch and EC2
  connectivity. Confirm final host and data-plane logs, node conditions and
  events, EC2 and Auto Scaling timestamps, console evidence, and a clear native
  capture failure remain available. Stop and revise the plan if that evidence
  cannot explain the motivating node-disconnection event.
- [x] 4.8 Run existing Helm lint, unit, and minikube render gates and confirm
  `src/groundx`, `helm`, and their rendered manifests are unchanged.
- [x] 4.9 Run strict OpenSpec validation.

Canary evidence, 2026-08-22: an authorized disposable EKS 1.35 cluster in
`us-west-1` ran `eks-node-monitoring-agent` `v1.7.0-eksbuild.1` on exactly one
CPU-only and one CPU-memory node. The node agent requested 10m CPU and 30 MiB,
limited 250m CPU and 200 MiB, used about 4 to 6m CPU and 49 to 51 MiB, and kept
its vendor tolerations and documented privileged host access. Its exact CPU-pool
affinity excluded other pools, NVIDIA monitoring was disabled, the DCGM selector
matched no node, and the existing CloudWatch add-on remained active. Both
reachable captures contained kernel, memory-pressure, storage, containerd, and
networking evidence; one also reported a missing optional VPC CNI IPAM file
without losing the other sources. A pre-existing capture was preserved, owned
captures were removed, and the disabled plan removed only this add-on.

At 02:53:28 UTC, the CPU-only node was denied only EKS API TCP/443 while EC2 and
CloudWatch connectivity remained available. Kubernetes changed it to
`NodeStatusUnknown` at 02:54:11 and marked an ordinary pod for eviction at
02:59:11. EC2 reachability and Auto Scaling health stayed healthy. CloudWatch
continued recording normal node CPU, memory, disk, and network metrics plus
kubelet connection failures to both EKS endpoint IPs after Kubernetes lost the
node. Native capture timed out clearly and cleaned up its owned request. The
EC2 console output remained available. The cluster, nodes, add-ons, IAM,
networking, logs, and Terraform state were then destroyed; no canary resources
remain.

## 5. Production Handoff

- [x] 5.1 Document the default-off setting, CPU-pool add-on impact, capture
  command, evidence locations, cost, disable procedure, and the fact that the
  feature does not repair nodes.
- [x] 5.2 Submit the verified implementation as a PR whose base branch is
  `0.2.7`; verify the PR does not target the repository default branch.
- [ ] 5.3 Obtain explicit production approval and review the production
  Terraform plan; do not use the auto-approved `bin/environment` wrapper.
- [ ] 5.4 Review one natural incident before proposing automatic capture,
  termination hooks, snapshots, or node repair.
