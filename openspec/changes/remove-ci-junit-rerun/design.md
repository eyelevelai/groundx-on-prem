## Design

The workflow calls `.build/bin/validate-helm.sh` without reporting arguments.
The script runs the existing Helm suite once, followed by its existing
snapshot stability and chart contract checks. Job failure still blocks
`On-Prem PR checks`, and test results remain available in Actions logs.

Both live Strimzi jobs run when `github.event_name` is `release` or
`workflow_dispatch`. Their installation, migration and failure checks remain
intact. The PR-only aggregate depends on `helm-unittest` and passes only when
that job succeeds. Draft PRs still fail before Helm setup.

The local reporting interface, branch-push checks and workflow event list
remain intact. The costs are losing the downloadable XML artifact and moving
live Kafka compatibility detection from PR validation to release/manual runs.

## Validation and rollout

Run actionlint and compare parsed workflow jobs and steps against the base:
only reporting, live-job scheduling and PR aggregate dependencies may change.
Check that PRs require Helm success and both live jobs run on release/manual
events. No local chart rerun is needed because chart inputs and tests are unchanged.
Merge into `0.3.0` through a draft PR; subsequent runs use the new command.
Revert the workflow change to restore the previous CI behavior. No deployment is required.
