## Context

The chart already renders an optional `engines.default.maxImages` value. The
application contract changed, but the chart contract still describes the old
document-summary fallback behavior.

## Goals / Non-Goals

**Goals:**

- Describe the current engine-wide, opt-in image count limit.

**Non-Goals:**

- No schema, template, chart, application, or deployment change.

## Decisions

Update only the OpenSpec contract. The existing schema and template already
render explicit positive values and omit missing or `null` values correctly.
Changing chart behavior would add risk without fixing the documentation gap.

## Risks / Trade-offs

- Stale application images can still implement older behavior. The contract
  identifies this as application-owned behavior.

## Migration Plan

No rollout, restart, migration, or state change is required. Merge the contract
with the compatible application release. Rollback restores the previous text.

## Open Questions

None.
