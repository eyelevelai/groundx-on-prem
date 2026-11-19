## Why

The Helm workflow reruns its full suite for an unused JUnit artifact and
runs live Kafka installation and migration tests on every ready PR. In run
44433765720, the reporting pass took 3 minutes 55 seconds. The live jobs
create Kubernetes clusters and validate upstream operator compatibility.
Feature-branch pushes also duplicate PR validation, and older revisions keep
running after a newer commit arrives.

## What Changes

- Run the production gate without `--junit` and remove its artifact upload.
- Run both live Strimzi jobs only on release or manual workflow events.
- Make `On-Prem PR checks` require only the Helm regression job.
- Limit push validation to `main` and numeric version branches such as `0.3.0`.
- Cancel older runs for the same PR or push branch; isolate release/manual runs.
- Preserve Helm snapshots, render checks, local reporting and test matrices.

## Impact

Only CI scheduling, reporting and contributor guidance change. No deployed
chart, credentials or stateful resources change in dev, staging or production.
PRs lose live Kafka compatibility verification; release and manual runs retain
it. Feature branches have no automatic test run until their PR is ready.
Only the latest PR or branch revision finishes automatic validation.
Reverting the workflow restores the previous scheduling and reporting.
