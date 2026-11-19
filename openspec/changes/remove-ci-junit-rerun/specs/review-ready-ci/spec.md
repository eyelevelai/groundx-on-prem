## ADDED Requirements

### Requirement: CI runs the Helm suite once

The Helm workflow SHALL invoke the production gate without `--junit` and
SHALL NOT upload `reports/helm-unittest.xml`. Existing test jobs, triggers,
snapshot guards and PR result dependencies SHALL remain unchanged.

#### Scenario: A workflow event runs Helm validation

- **WHEN** a push, ready PR, release or manual event runs the Helm job
- **THEN** the production gate runs without the duplicate JUnit reporting pass
- **AND** the existing gate exit status determines job success
