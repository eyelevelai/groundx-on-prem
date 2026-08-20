## Why

The 0.2.7 values schema accepts `cluster.hasMig` and `cluster.tls.existingSecret`, but the current chart does not consume either field. Schema-valid no-op settings can make an operator believe MIG scheduling or cluster-wide TLS is active when rendered resources are unchanged.

## What Changes

- Mark both accepted no-op fields as deprecated and document their actual behavior in the schema.
- Remove the unused `groundx.hasMig` helper and the Helm note that reads the nonexistent top-level `tls.existingSecret` path.
- Add executable contract tests proving the fields remain schema-compatible and do not alter rendered manifests.
- Preserve supported alternatives: explicit per-workload GPU resource and node settings for MIG, per-ingress TLS, and database root certificates.
- No cluster resources change on upgrade. Dev, staging, and production values remain schema-compatible, and no stateful resource is affected.
- Rollback is a chart-code revert. Rollforward is the same metadata and test change on the next chart release.
- Open design questions: none. A boolean does not identify a MIG resource profile, and one Secret name does not define which workloads, ports, or trust stores should use cluster-wide TLS.

## Capabilities

### New Capabilities

- `values-contract-semantics`: Distinguishes accepted compatibility fields from values that change rendered deployment behavior.

### Modified Capabilities

None.

## Impact

- `src/groundx/values.schema.json`, helper and note templates, and Helm tests.
- The manual `helm/` mirror receives the matching schema, helper, and note changes.
- No application image, Kubernetes API, persisted data, Secret content, or live workload template changes.
