## MODIFIED Requirements

### Requirement: Every render gate supplies test-only search passwords from one fixture
Every CI, gate, and declared render command that renders a non-ingest configuration SHALL keep supplying test-only search passwords from a single literal-free fixture under `src/groundx/tests/files/`, so the rendered output and the helm-unittest snapshots carry explicit test credentials. Nothing SHALL be added to `values/minikube` or any install example to satisfy this. helm-unittest snapshots SHALL NOT depend on a chart default, and the chart no longer fails a render that omits the fixture.

#### Scenario: Gate and declared commands use the fixture (polarity: reject before state)
- **WHEN** `.build/bin/validate-helm.sh` runs on the changed chart
- **THEN** it passes, and the workflow, `service.yaml`, `openspec/config.yaml` and `docs/agents/repository-guide.md` render commands reference the fixture

#### Scenario: A render without the fixture succeeds and carries no search password (polarity: accept and enqueue)
- **WHEN** a non-ingest render is attempted without search passwords
- **THEN** it succeeds, because the operator may supply the passwords through the cluster credentials Secret
- **AND** it is not satisfied by a default: the rendered config carries no search `password:` line
