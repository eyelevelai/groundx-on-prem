## ADDED Requirements

### Requirement: CI runs the Helm suite once

The Helm workflow SHALL invoke the production gate without `--junit` and
SHALL NOT upload `reports/helm-unittest.xml`. Existing Helm regression tests
and snapshot guards SHALL remain unchanged.

#### Scenario: A workflow event runs Helm validation

- **WHEN** a push, ready PR, release or manual event runs the Helm job
- **THEN** the production gate runs without the duplicate JUnit reporting pass
- **AND** the existing gate exit status determines job success

### Requirement: Live Kafka validation runs outside PR checks

Both live Strimzi installation and migration jobs SHALL run on release and
manual workflow events, and SHALL skip branch-push and pull-request events.
Their test steps SHALL remain unchanged.

#### Scenario: Release or manual validation

- **WHEN** a release event or manual workflow dispatch starts validation
- **THEN** both live Strimzi jobs run alongside Helm validation

## MODIFIED Requirements

### Requirement: Review-ready regression checks

On-Prem CI SHALL require successful Helm regression checks for the review-ready
PR revision and SHALL preserve branch-push, release and manual validation.
Live Kafka validation SHALL NOT be a PR result dependency.

#### Scenario: Ready PR revision

- **WHEN** a human marks a draft ready or updates a ready PR
- **THEN** the PR-only check passes only after Helm succeeds
- **AND** it does not wait for live Kafka installation or migration tests
