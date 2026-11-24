# inference-gpu-rollout-strategy Specification

## Purpose
TBD - created by archiving change gx-117-upgrading-groundx-on-one-gpu-nodes. Update Purpose after archive.
## Requirements
### Requirement: GPU inference Deployments free the GPU before the new pod starts
When `updateStrategy` is empty and a container of an inference Deployment asks for `nvidia.com/gpu` greater than 0 in `requests` or `limits`, the chart SHALL render `strategy.type: RollingUpdate` with `rollingUpdate.maxSurge: 0` and `progressDeadlineSeconds` equal to the service's termination grace period plus 600. The quantity SHALL be compared as a number, so an int, a float and a quoted string behave alike. Polarity: `finalize success`.

#### Scenario: Default layout inference
- **GIVEN** the default values
- **WHEN** `layout-inference` renders
- **THEN** `spec.strategy.type` is `RollingUpdate`, `maxSurge` is 0 and `progressDeadlineSeconds` is 1500

#### Scenario: Deadline follows a grace period override
- **GIVEN** `ranker.inference.replicas.gracePeriod: 120`
- **WHEN** `ranker-inference` renders
- **THEN** `terminationGracePeriodSeconds` is 120, `progressDeadlineSeconds` is 720 and `layout-inference` stays at 1500

#### Scenario: Quoted GPU quantity
- **GIVEN** `layout.inference.resources` sets `nvidia.com/gpu: "1"` and `layout.inference.replicas.gracePeriod: 100`
- **WHEN** `layout-inference` renders
- **THEN** the strategy is `RollingUpdate` with `maxSurge` 0 and `progressDeadlineSeconds` is 700

#### Scenario: GPU on one side only
- **GIVEN** layout sets `nvidia.com/gpu` in `requests` only and ranker sets it in `limits` only
- **WHEN** `layout-inference` and `ranker-inference` render
- **THEN** both render `RollingUpdate` with `maxSurge` 0 and `progressDeadlineSeconds`

### Requirement: A GPU pod that does not ask for a GPU is recreated
When `updateStrategy` is empty and an inference Deployment runs on a GPU (its `deviceType` is not `cpu`) but no container asks for `nvidia.com/gpu` greater than 0, the chart SHALL render `strategy.type: Recreate` and `progressDeadlineSeconds` equal to the service's termination grace period plus 600. The scheduler cannot see GPU memory that pods share, so a rolling update would start the new pod beside the old one, and `maxSurge: 0` would not hold it back. Polarity: `finalize success`.

#### Scenario: Default summary
- **GIVEN** the default values
- **WHEN** `summary-inference` renders
- **THEN** `spec.strategy.type` is `Recreate`, `rollingUpdate` is absent and `progressDeadlineSeconds` is 900

#### Scenario: Summary deadline follows a grace period override
- **GIVEN** `summary.inference.replicas.gracePeriod: 150`
- **WHEN** `summary-inference` renders
- **THEN** `spec.strategy.type` is `Recreate` and `progressDeadlineSeconds` is 750

### Requirement: An explicit updateStrategy takes precedence
When `updateStrategy` is set, the chart SHALL render only `strategy.type` with that value and neither `rollingUpdate` nor `progressDeadlineSeconds`, whatever the GPU request. Polarity: `skip unrelated repair path`.

#### Scenario: Explicit Recreate with a GPU request
- **GIVEN** `summary.inference.updateStrategy: Recreate` and a summary GPU request of 1
- **WHEN** `summary-inference` renders
- **THEN** `spec.strategy.type` is `Recreate` and `rollingUpdate` and `progressDeadlineSeconds` are absent

#### Scenario: Existing values with an explicit strategy keep their render
- **GIVEN** a values file written before this change that sets `updateStrategy: Recreate`
- **WHEN** the chart renders after this change
- **THEN** the strategy block is unchanged and the file still validates against the schema

### Requirement: Deployments that do not run on a GPU render as before
The chart SHALL render no `strategy` and no `progressDeadlineSeconds` when `deviceType` is `cpu` and no container asks for a GPU quantity greater than 0: layout in CPU mode, a quoted `"0"`, or a missing `resources`, `requests`, `limits` or GPU key. Polarity: `skip unrelated repair path`.

#### Scenario: Layout in CPU mode
- **GIVEN** `layout.inference.deviceType: cpu`
- **WHEN** `layout-inference` renders
- **THEN** `spec.strategy` and `spec.progressDeadlineSeconds` are absent

#### Scenario: Zero quoted quantity and a missing limits block
- **GIVEN** `ranker.inference.deviceType: cpu`, ranker `requests` sets `nvidia.com/gpu: "0"` and `limits` is removed
- **WHEN** `ranker-inference` renders
- **THEN** `spec.strategy` and `spec.progressDeadlineSeconds` are absent

### Requirement: Upgrade guidance matches the new default
`docs/upgrades.md` SHALL state that GPU-requesting inference Deployments now roll with `maxSurge` 0, that a summary pod that shares the GPU without asking for it renders `Recreate`, that each pod-template change leaves no running pod from the old pod's stop until the new pod is Ready, that `updateStrategy: RollingUpdate` opts out, and that `kubectl rollout status` is the completion check. It SHALL no longer say a GPU request needs `updateStrategy: Recreate` to avoid a Pending pod. Polarity: `finalize success`.

#### Scenario: Stale sentence removed
- **GIVEN** the updated `docs/upgrades.md`
- **WHEN** a reader looks for the old advice to keep `Recreate` unless a spare GPU is free
- **THEN** it is absent and the new default, outage, opt-out and completion check are present

