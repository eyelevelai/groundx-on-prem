## Design

The workflow calls `.build/bin/validate-helm.sh` without reporting arguments.
The script runs the existing Helm suite once, followed by its existing
snapshot stability and chart contract checks. Job failure still blocks
`On-Prem PR checks`, and test results remain available in Actions logs.

Both live Strimzi jobs run when `github.event_name` is `release` or
`workflow_dispatch`. Their installation, migration and failure checks remain
intact. The PR-only aggregate depends on `helm-unittest` and passes only when
that job succeeds. Draft PRs still fail before Helm setup.

Push events match `main` and `[0-9]+.[0-9]+.[0-9]+`, covering numeric version
branches without adding each release to the workflow. Feature changes run
through ready PRs instead of both push and PR events.

Concurrency groups include workflow name, event type and PR number or push
ref. A new run cancels an older run only for the same PR or push branch.
Release and manual groups use the run ID and never enable cancellation,
so they neither interrupt each other nor replace pending runs.

The local reporting interface and all test cases remain intact. The costs
are losing the XML artifact, moving live Kafka checks to release/manual runs,
and withholding automatic feature-branch tests until a PR is ready.

## Validation and rollout

Run actionlint and compare parsed workflow jobs and steps against the base:
only reporting, event filters, concurrency, live-job scheduling and PR aggregate
dependencies may change. Check push filters, PR/branch isolation and unique
release/manual groups. PRs must require Helm success and both live jobs must
run on release/manual events. No local chart rerun is needed because chart
inputs and tests are unchanged.
Merge into `0.3.0` through a draft PR; subsequent runs use the new command.
Revert the workflow change to restore the previous CI behavior. No deployment is required.
