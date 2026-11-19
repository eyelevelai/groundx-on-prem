## Why

The Helm workflow reruns its full suite for an unused JUnit artifact and
runs live Kafka installation and migration tests on every ready PR. In run
44433765720, the reporting pass took 3 minutes 55 seconds. The live jobs
create Kubernetes clusters and validate upstream operator compatibility.

## What Changes

- Run the production gate without `--junit` and remove its artifact upload.
- Run both live Strimzi jobs only on release or manual workflow events.
- Make `On-Prem PR checks` require only the Helm regression job.
- Preserve Helm snapshots, render checks, local reporting and push validation.

## Impact

Only CI scheduling, reporting and contributor guidance change. No deployed
chart, credentials or stateful resources change in dev, staging or production.
PRs lose live Kafka compatibility verification; release and manual runs retain
it. Reverting the workflow restores PR live tests and the XML artifact.
