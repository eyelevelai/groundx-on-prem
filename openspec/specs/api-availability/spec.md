# API availability Specification

## Purpose
Define opt-in PodDisruptionBudget behavior for GroundX API workloads while preserving existing replica defaults and enabling hosted protection only where redundant replicas exist.
## Requirements
### Requirement: Every API exposes the same opt-in disruption budget

The chart SHALL expose an optional disruption budget for `groundx`, `extract-api`, `layout-api`, `ranker-api`, `summary-api`, and `workspace-api` through each service's values and settings helper. On Kubernetes 1.26 and newer, every rendered budget SHALL set `unhealthyPodEvictionPolicy: AlwaysAllow`, so a running but not-ready pod can be evicted by a drain even when the service is below its budget. On older Kubernetes versions, the chart SHALL omit this field while retaining the budget. Kubernetes 1.26 requires the alpha feature gate for the policy to take effect. The policy SHALL NOT be configurable.

Polarity: `accept and enqueue`.

#### Scenario: An API budget is enabled

- **GIVEN** any supported API is enabled
- **AND** its disruption budget is enabled
- **AND** Helm reports Kubernetes 1.26 or newer
- **WHEN** Helm renders the chart
- **THEN** one PodDisruptionBudget is rendered for that API
- **AND** it requires one available pod
- **AND** it sets `unhealthyPodEvictionPolicy: AlwaysAllow`
- **AND** its selector matches the API Deployment

#### Scenario: A budget is enabled on Kubernetes before 1.26

- **GIVEN** an enabled API or worker with its disruption budget enabled
- **AND** Helm reports Kubernetes older than 1.26
- **WHEN** Helm renders either chart surface
- **THEN** its PodDisruptionBudget retains `minAvailable: 1` and the service selector
- **AND** the unsupported `unhealthyPodEvictionPolicy` field is absent

### Requirement: Generic deployments retain existing availability defaults

The chart SHALL keep all disruption budgets disabled, render no topology spread constraints and keep replica defaults unchanged unless an operator opts in.

Polarity: `skip unrelated repair path`.

#### Scenario: Default chart render

- **GIVEN** the default chart values
- **WHEN** Helm renders the chart
- **THEN** no disruption budget is rendered
- **AND** no `topologySpreadConstraints` field is rendered
- **AND** the extract API replica default remains one
- **AND** existing render snapshots are unchanged

### Requirement: Hosted production preserves redundant APIs during voluntary eviction

The hosted EKS deployment SHALL protect each enabled API that already has at least two minimum replicas.

#### Scenario: Hosted production render

- **GIVEN** `values.ranker-only-eks.yaml`
- **WHEN** Helm renders either chart surface
- **THEN** the extract API Deployment requests two replicas
- **AND** its HPA minimum is two
- **AND** its PodDisruptionBudget has `minAvailable: 1`
- **AND** `ranker-api` remains absent in ingest-only mode
- **AND** single-replica APIs do not render a budget

### Requirement: The deployment contract is strict and mirrored

The source and published chart surfaces SHALL expose and render the same disruption-budget and topology-spread contract. Both keys SHALL be declared as named objects in `values.schema.json` with `additionalProperties: false` kept, so an unknown key under any service still fails validation.

#### Scenario: Both chart surfaces validate

- **GIVEN** the disruption-budget and topology-spread values
- **WHEN** schema, unit, lint, and render validation run
- **THEN** both chart surfaces accept and render the same budgets and spread constraints

#### Scenario: An unknown key is still rejected (catches)

- **GIVEN** a service that gains the new keys and an unrelated unknown key under it
- **WHEN** Helm validates the values
- **THEN** validation fails on the unknown key

### Requirement: Every long-running chart workload exposes an opt-in disruption budget

The chart SHALL expose an optional `disruptionBudget.enabled` for every long-running chart workload except the bundled Redis StatefulSets: `summaryClient`, `preProcess`, `process`, `queue`, `upload`, `largeFileDeliver`, `layoutWebhook`, `metrics`, the Celery workers under `layout`, `extract` and `workspace`, and the `layout`, `ranker` and `summary` inference services. An enabled budget SHALL be a `policy/v1` PodDisruptionBudget with `minAvailable: 1` whose name and selector are that service's own Deployment name. The chart SHALL set `unhealthyPodEvictionPolicy: AlwaysAllow` on Kubernetes 1.26 and newer and omit that field on older Kubernetes versions. The `minAvailable` value and the eviction policy SHALL NOT be configurable.

Polarity: `accept and enqueue`.

#### Scenario: A worker budget is enabled

- **GIVEN** a Go worker, the metrics service or an inference service is enabled
- **AND** its `disruptionBudget.enabled` is true
- **AND** Helm reports Kubernetes 1.26 or newer
- **WHEN** Helm renders the chart
- **THEN** one PodDisruptionBudget with `minAvailable: 1` and `unhealthyPodEvictionPolicy: AlwaysAllow` is rendered for that service
- **AND** its selector matches only that service's Deployment pods

#### Scenario: Celery budgets stay per worker (catches)

- **GIVEN** `layout.map` and `layout.ocr` are both enabled with `disruptionBudget.enabled` true
- **AND** Helm reports Kubernetes 1.26 or newer
- **WHEN** Helm renders the chart
- **THEN** two PodDisruptionBudgets are rendered, named and selecting `layout-map` and `layout-ocr` respectively
- **AND** each sets `unhealthyPodEvictionPolicy: AlwaysAllow`
- **AND** neither is named or selecting the group name `layout`

#### Scenario: A disabled budget renders no policy (must not block)

- **GIVEN** a listed service is enabled with `disruptionBudget.enabled` left at its default
- **WHEN** Helm renders the chart
- **THEN** no PodDisruptionBudget is rendered for that service
- **AND** no `unhealthyPodEvictionPolicy` field appears in its rendered output

### Requirement: Every listed workload exposes opt-in topology spread constraints

The chart SHALL accept an optional `topologySpreadConstraints` list on `groundx`, the five API services and every service that gains a disruption budget, and SHALL render it unchanged as `topologySpreadConstraints` on that service's pod spec. The chart SHALL NOT inject a `labelSelector`. When the list is unset or empty, nothing SHALL be rendered.

Polarity: `accept and enqueue`.

#### Scenario: Spread constraints are set

- **GIVEN** a listed service is enabled with a `topologySpreadConstraints` list
- **WHEN** Helm renders the chart
- **THEN** that service's Deployment pod spec carries exactly that list

#### Scenario: Spread on a service without a budget (must not block)

- **GIVEN** `layout.api` and `groundx` are enabled with `topologySpreadConstraints` and no disruption budget
- **WHEN** Helm renders the chart
- **THEN** both Deployments carry the list
- **AND** no PodDisruptionBudget is rendered

