## Why

FRA-223 reports new GroundX images running against an older database schema. Checking the old API's health or the database TCP port cannot establish compatibility for a new worker.

## What Changes

Run the target GroundX image's migration-only command as a pre-upgrade Job before regular release resources change. A dedicated hook Secret supplies target config without changing running pods. Extend the existing Go service tests and mirror the shipping templates.

## Capabilities

### New Capabilities
- `database-upgrade-gate`: database upgrades block incompatible application rollout.

## Impact

All chart upgrades with Go API or ingestion workloads gain a blocking migration step, including worker-only installations. Fresh installs retain GroundX startup initialization. No new config.yaml setting or separate migration image is introduced. Requires the companion Cashbot implementation before deployment. No cluster or database is changed by this PR.

Failure retains the old application resources and migration diagnostics. Already committed additive SQL is not undone; rollback retains the schema. Open questions: none.
