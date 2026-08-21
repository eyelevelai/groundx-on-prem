## ADDED Requirements

### Requirement: Diagnostics are explicitly enabled

The AWS EKS Terraform SHALL expose `node_diagnostics.enabled` as the only
required operator input for node diagnostics, and it SHALL default to `false`.

#### Scenario: Setting is omitted

- **GIVEN** `node_diagnostics` is omitted
- **WHEN** Terraform plans the EKS stack
- **THEN** the effective value is disabled
- **AND** no diagnostic add-on, permission, host configuration, or Helm change
  is planned.

#### Scenario: Setting is false

- **GIVEN** `node_diagnostics.enabled` is `false`
- **WHEN** Terraform plans the EKS stack
- **THEN** the diagnostic plan is identical to the omitted-setting plan.

#### Scenario: Setting is true

- **GIVEN** `node_diagnostics.enabled` is `true`
- **WHEN** Terraform plans the EKS stack
- **THEN** it conditionally adds one pinned, cluster-compatible EKS Node
  Monitoring Agent add-on
- **AND** it requires no other diagnostic value.

### Requirement: Enabled diagnostics use AWS-native node health

Enabled diagnostics SHALL use the EKS Node Monitoring Agent to publish node
health conditions and events and SHALL NOT enable automatic node repair.

#### Scenario: Add-on is enabled

- **GIVEN** diagnostics are enabled
- **WHEN** the pinned add-on is deployed
- **THEN** its node agent runs only on the CPU-only and CPU-memory worker pools
  selected by their configured labels
- **AND** the add-on supports the `NodeDiagnostic` `node` destination required
  for local bundle download
- **AND** its NVIDIA monitor and DCGM component do not run on GPU nodes
- **AND** existing CloudWatch GPU monitoring remains unchanged
- **AND** kernel, networking, container-runtime, storage, and memory findings
  can appear as node conditions or events
- **AND** no node is automatically repaired, restarted, or replaced.

#### Scenario: CPU incident is investigated

- **GIVEN** the affected node belongs to the CPU-only or CPU-memory pool
- **WHEN** an operator begins a CPU-node investigation
- **THEN** the operator selects the exact failed node by default
- **AND** the node agent is already scheduled on that pool.

### Requirement: Reachable nodes use native diagnostic bundles

The operator workflow SHALL use one repo-owned, exact-node command over the Node
Monitoring Agent's native `NodeDiagnostic` API for local host evidence capture.
It SHALL atomically own and clean up only the resource created by that
invocation. It SHALL NOT implement batch or S3 upload behavior.

#### Scenario: A node can return a bundle

- **GIVEN** diagnostics are enabled
- **AND** the affected node can serve a `NodeDiagnostic` request
- **WHEN** the operator runs the documented capture command
- **THEN** it creates a temporary `NodeDiagnostic` only if none exists for the
  target
- **AND** that resource produces a host log bundle
- **AND** the bundle is downloaded locally
- **AND** cleanup deletes only the same resource UID created by that invocation
- **AND** no GroundX workload or cluster capacity is modified.

#### Scenario: A selected node already has an active capture

- **GIVEN** a selected node has an existing `NodeDiagnostic`
- **WHEN** the operator attempts the atomic create
- **THEN** capture stops for that target
- **AND** the existing resource is not deleted, replaced, or overlapped.

#### Scenario: The resource name is reused before cleanup

- **GIVEN** the command created a `NodeDiagnostic` and recorded its UID
- **AND** that resource is replaced by another resource with the same node name
- **WHEN** the command performs cleanup
- **THEN** the replacement resource is not deleted.

### Requirement: Incident evidence is correlated outside the bundle

The operator workflow SHALL correlate the native bundle with existing
Kubernetes and AWS evidence using UTC timestamps, node name, and EC2 instance
ID.

#### Scenario: Operator records an incident

- **WHEN** diagnostic collection begins
- **THEN** the workflow records node conditions, bound pods, recent events,
  existing CloudWatch node metrics and logs, EC2 status, Auto Scaling activity,
  and EC2 console output when available
- **AND** all normal collection steps are read-only except creation and cleanup
  of the temporary `NodeDiagnostic`.

### Requirement: Unreachable-node fallback remains explicit

The operator workflow SHALL report native collection failure and SHALL NOT
automatically mutate infrastructure to preserve evidence.

#### Scenario: Node cannot return a bundle

- **GIVEN** diagnostics are enabled
- **WHEN** `NodeDiagnostic` cannot complete
- **THEN** the workflow preserves the node, instance, and incident identifiers
- **AND** it gathers the remaining existing Kubernetes, CloudWatch, EC2, Auto
  Scaling, and console evidence
- **AND** it identifies a root-volume snapshot as a separate action requiring
  explicit approval when offline disk evidence is needed.

#### Scenario: Unreachable-node fallback is canaried

- **GIVEN** separate authorization and a disposable non-production CPU node
- **WHEN** EKS API connectivity is removed while CloudWatch and EC2 connectivity
  remain available until `NodeDiagnostic` cannot complete
- **THEN** final host and data-plane logs, node conditions and events, EC2 and
  Auto Scaling timestamps, console evidence, and the native capture failure are
  collected
- **AND** rollout stops for plan revision if that evidence cannot explain the
  motivating node-disconnection event.

#### Scenario: Reachable bundle coverage is checked

- **GIVEN** a disposable non-production CPU node can return a bundle
- **WHEN** the operator captures and inspects it
- **THEN** the bundle contains the expected kernel, memory, storage,
  container-runtime, and networking evidence sources
- **AND** rollout stops for plan revision if required sources are absent.

### Requirement: Diagnostics do not repair or resize the cluster

This capability SHALL collect evidence only. It SHALL NOT automatically
restart, reboot, replace, scale, cordon, drain, delete, or delay termination of
nodes or pods.

#### Scenario: Evidence capture completes or fails

- **WHEN** native capture succeeds or fails
- **THEN** desired, minimum, and maximum node-group capacity are unchanged
- **AND** remediation still requires a separate explicit change.

### Requirement: Diagnostic bundles are handled as sensitive evidence

The operator workflow SHALL keep bundle storage and sharing explicit.

#### Scenario: Bundle is downloaded

- **WHEN** an operator receives a diagnostic bundle
- **THEN** it is stored locally
- **AND** it is not committed, attached to a ticket, or shared outside the
  approved incident path without review.

#### Scenario: Manual S3 collection is required

- **WHEN** an operator chooses AWS's manual S3 collection path
- **THEN** it uses an existing approved bucket and retention policy
- **AND** this capability does not create or own a diagnostic bucket or upload
  logic.

#### Scenario: Diagnostics are disabled

- **WHEN** the operator sets `node_diagnostics.enabled` to `false`
- **THEN** the managed add-on is removed and new native captures stop
- **AND** previously saved bundles are not deleted by Terraform.

### Requirement: GroundX Helm behavior remains unchanged

The diagnostics capability SHALL remain AWS infrastructure configuration and
SHALL NOT modify the GroundX application chart or its published mirror.

#### Scenario: Diagnostics are implemented

- **WHEN** the implementation diff is reviewed
- **THEN** `src/groundx`, `helm`, GroundX workloads, queues, databases, caches,
  object stores, HPAs, and application images are unchanged
- **AND** non-AWS deployments are unaffected.
