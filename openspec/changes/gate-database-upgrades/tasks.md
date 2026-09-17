## Implementation

- [x] Add failing upgrade assertions and snapshots to existing Go service/resource tests.
- [x] Render an upgrade-only config Secret and migration Job with normal GroundX image/security settings.
- [x] Preserve fresh installs, disabled and worker-only configurations, environment overrides and service isolation.
- [x] Mirror source changes into helm/ and pass the existing full chart gate.
- [x] Document image ordering, migration cost, failure diagnostics, rollback and no-hooks behavior.
- [ ] Review, push and open the dependent 0.2.7 PR. Deployment remains a separate approval.
