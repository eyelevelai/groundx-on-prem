## Why

An existing release upgraded with `--reuse-values --set metrics.replicas.gracePeriod=77` retains chart defaults that omit `metrics.replicas.desired`. Schema validation rejects the upgrade even though the Metrics helper already defaults an omitted replica count to one.

## What Changes

Make `metrics.replicas.desired` optional and supply its default in the existing Metrics replicas helper. Preserve explicit counts, including zero. Mirror the schema and helper into `helm/` and extend the existing Metrics tests.

This affects self-hosted chart consumers. Existing values render identically. Release through the normal chart upgrade, with rollback by reverting this change. Open design questions are settled.

## Capabilities

Modify `queue-service-grace-period` to support Metrics grace overrides with reused release values.
