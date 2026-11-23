# review-ready-ci Specification

## Purpose
Define Helm regression checks for PRs and release branches, separate live
Kafka validation, and control duplicate and superseded workflow runs.

## Requirements

### Requirement: Review-ready regression checks

On-Prem CI SHALL require successful Helm regression checks for the review-ready
PR revision and SHALL preserve release and manual validation. Push validation
SHALL run only on `main` and numeric version branches matching
`[0-9]+.[0-9]+.[0-9]+`, not on feature branches.
Live Kafka validation SHALL NOT be a PR result dependency.

#### Scenario: Ready PR revision

- **WHEN** a human marks a draft ready or updates a ready PR
- **THEN** the PR-only check passes only after Helm succeeds
- **AND** it does not wait for live Kafka installation or migration tests

#### Scenario: Feature-branch update

- **WHEN** a commit is pushed to a feature branch with a ready PR
- **THEN** PR validation runs without a duplicate push-triggered run

#### Scenario: Main or version-branch update

- **WHEN** a commit is pushed to `main` or a numeric version branch
- **THEN** push-triggered Helm validation runs

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

### Requirement: Superseded automatic runs are canceled

A newer PR run SHALL cancel older runs for the same PR. A newer push run
SHALL cancel older push runs for the same branch. Concurrency groups SHALL
include workflow and event identity. Release and manual runs SHALL use
unique groups and SHALL NOT cancel or replace each other.

#### Scenario: A PR receives another commit

- **WHEN** a newer run starts for the same PR
- **THEN** the previous run for that PR is canceled
- **AND** other PRs and push, release and manual runs remain independent

#### Scenario: Repeated release or manual validation

- **WHEN** multiple release or manual runs target the same ref
- **THEN** each has its own group and can finish independently
