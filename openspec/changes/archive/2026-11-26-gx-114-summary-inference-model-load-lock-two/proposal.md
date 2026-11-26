## Why

Summary-inference gains a file lock on its model volume (`initializing.flock`) that serializes model loads across workers and pods. The upgrade that introduces it has two operator-visible effects that `docs/upgrades.md` does not mention: old and new pods can overlap during the rollout, and the model volume now needs file-lock support. Operators need both stated where they already read the `Recreate` / scale-to-zero guidance.

## What Changes

- Add a few sentences to `docs/upgrades.md`, next to the existing summary `updateStrategy: Recreate` and scale-to-zero guidance:
  - During the upgrade that introduces the lock, an old pod that restarts while old and new pods overlap can load its model alongside a new pod. Setting `summary.inference.updateStrategy: Recreate`, or scaling summary-inference to zero before upgrading, removes the overlap.
  - Summary-inference now needs file-lock support on its model volume. It was tested on EFS only. On storage that rejects locks the worker logs the lock error (`model load failed; exiting worker`) and restarts, so summary does not come up. Remedy: use a storage class with lock support, or roll the chart back.
- No new procedure section. No chart, template, values, or snapshot change.

## Capabilities

### New Capabilities
- `summary-inference-lock-upgrade-guidance`: the upgrade guide states the old/new pod overlap risk with its `Recreate` / scale-to-zero remedy, and the file-lock storage requirement with its symptom and remedy.

### Modified Capabilities

None. Existing specs (`inference-model-download-lock`, `existing-redis-tls-upgrade-guidance`) keep their requirements; this change only documents.

## Impact

- **Files:** `docs/upgrades.md` only.
- **Blast radius:** none at runtime. No environment redeploys, no chart version change, no rendered-manifest change. Dev, staging and prod are unaffected by this change itself; the guidance applies to operators of clusters upgrading to the chart release that ships the lock.
- **Stateful resources:** none touched. The note concerns the existing summary model volume claim.
- **Rollback / roll-forward:** revert the doc edit; nothing else depends on it.
- **Open design questions:** none (checked against AGENTS.md and existing specs).
