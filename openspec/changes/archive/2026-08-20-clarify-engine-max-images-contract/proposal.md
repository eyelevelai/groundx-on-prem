## Why

The chart contract still describes `maxImages` as a document-summary limit with
an application fallback. Compatible application images now treat it as an
optional engine-wide request limit, with no count limit when it is omitted.

## What Changes

- Describe `engines.default.maxImages` as an engine request image limit.
- State that omission or `null` leaves requests uncapped by image count.
- Keep the chart schema and rendering unchanged.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `doc-summary-image-limit-config`: Align the chart contract with current
  application behavior.

## Impact

This is documentation only. It changes no chart output, Kubernetes resource,
deployment, data, or stateful service in any environment. Rollback restores the
previous wording. Rollforward merges the corrected contract. Open design
questions: none.
