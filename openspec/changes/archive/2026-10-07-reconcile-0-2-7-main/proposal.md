## Why

The 0.2.7 release branch and main contain independent chart changes and conflict when merged. Reconcile them before promoting 0.2.7 so the ingress routing fix and managed-data TLS support both reach main.

## What Changes

- Merge main into the release branch, retaining the generated Ingress backend fix and contributor guidance.
- Retain 0.2.7 workspace TLS configuration, Secret-backed configuration, authenticated Redis URLs, and existing regression coverage.
- Repackage the reconciled source chart and replace the unpacked helm snapshot with that package's contents.
- Validate the reconciled chart through the existing production gate and PR integration jobs.

## Capabilities

### New Capabilities

- `release-chart-artifacts`: The release package and unpacked chart represent the same reconciled source chart.

### Modified Capabilities

None. Existing chart requirements remain in force.

## Impact

This changes repository contents and release artifacts. No dev, staging, or production cluster is redeployed, and no persistent data changes occur. Publishing the rebuilt chart and installing it are separate operator actions. Revert the reconciliation commit and its generated artifacts together to roll back; roll forward by repackaging corrected source.

Open design questions: none.
