## ADDED Requirements

### Requirement: Ranker inference uses worker-aware HTTP health probes

The chart SHALL use the ranker health server for Kubernetes liveness and
readiness, matching layout and summary inference.

#### Scenario: Ranker inference is rendered

- **GIVEN** ranker inference is enabled
- **WHEN** the chart renders the ranker Deployment
- **THEN** liveness uses HTTP `GET /alive` on port `8080`
- **AND** readiness uses HTTP `GET /health` on port `8080`
- **AND** ranker readiness does not use a process-name check.

#### Scenario: Ranker workers are not registered

- **GIVEN** fewer ranker workers are registered than the configured worker count
- **WHEN** Kubernetes polls `/health`
- **THEN** the endpoint reports that ranker inference is not ready.

#### Scenario: Ranker workers are idle

- **GIVEN** all ranker workers are registered and no requests are running
- **WHEN** Kubernetes continues polling `/health`
- **THEN** worker availability records remain present for the external HPA
  metric.

### Requirement: Ranker workers restore availability

Each ranker worker SHALL report itself available after request handling ends.

#### Scenario: Ranker inference succeeds

- **GIVEN** a ranker worker accepts a valid request
- **WHEN** inference completes
- **THEN** the worker reports itself available.

#### Scenario: Ranker inference fails

- **GIVEN** a ranker worker accepts a request
- **WHEN** validation or inference fails
- **THEN** the worker reports itself available before the failure returns.

### Requirement: Hosted ranker HPA scales earlier

The hosted ranker configuration SHALL preserve one always-on replica and begin
scale-up before the current replica is saturated.

#### Scenario: Hosted ranker HPA is rendered

- **GIVEN** the hosted EKS ranker values file
- **WHEN** the chart renders the ranker HPA
- **THEN** minimum replicas is `1`
- **AND** maximum replicas is `4`
- **AND** each ranker external metric target is `0.4`
- **AND** scale-up stabilization is `15` seconds
- **AND** scale-down stabilization remains `150` seconds.

#### Scenario: Hosted ranker traffic is idle

- **GIVEN** traffic has subsided and scale-down completes
- **WHEN** the HPA reaches its configured minimum
- **THEN** one ranker inference replica remains running.

### Requirement: Node provisioning remains unchanged

This change SHALL not modify GPU node or Cluster Autoscaler configuration.

#### Scenario: The change is implemented

- **WHEN** the implementation diff is reviewed
- **THEN** no node type, node group, scheduling label, taint, or Cluster
  Autoscaler setting has changed
- **AND** no deployment has been performed.
