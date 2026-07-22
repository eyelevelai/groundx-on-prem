## Goals / Non-Goals

**Goals:**
- Make `layout.inference.pvc` a schema-legal key in both `src/groundx/values.schema.json` (source
  of truth) and `helm/values.schema.json` (manual mirror), matching `ranker.inference.pvc` exactly.
- Keep the two schema files byte-identical after the edit (no drift beyond this change).

**Non-Goals:**
- No template change — `templates/_helpers/app/layout-inference.tpl` and
  `templates/app/inference.yaml` already implement PVC rendering for `layout.inference.pvc`; this
  change only removes the schema-level block.
- No `Chart.yaml` version bump (already `0.2.7` on this branch) and no `src/build.sh` publish.
- No change to any default value, replica count, or node-group/AZ configuration — enabling the
  actual EFS-RWX cutover for `layout-inference` and raising its replica count is a separate,
  later change this fix unblocks.
- No new subsystem, API shape, or status/lifecycle concept.

## Decisions

### 1. Insertion point and shape — verbatim mirror, confirmed against code on `origin/0.2.7`

`src/groundx/values.schema.json` top-level key `layout` (opens at line 622) has an `inference`
block (lines 722-763) with `additionalProperties: false` and properties in alphabetical order:
`affinity, annotations, containerPort, containerSecurityContext, deviceType, enabled, image,
imagePullPolicy, labels, node, nodeSelector, queue, replicas, resources, securityContext,
serviceAccount, threads, tolerations, updateStrategy, workers`. There is no `pvc` key.

The sibling top-level key `ranker`'s `inference` block already defines (confirmed at
`src/groundx/values.schema.json:1242-1249`):

```json
"pvc": {
  "type": "object",
  "properties": {
    "access": { "type": "string" },
    "capacity": { "type": "string" },
    "class": { "type": "string" },
    "name": { "type": "string" }
  },
  "additionalProperties": false
},
```

**Decision:** insert this exact block, unmodified, into `layout.inference.properties`, alphabetically
between `nodeSelector` (line 735) and `queue` (line 736) — i.e. immediately after the
`"nodeSelector": { "type": "object" },` line and before `"queue": { "type": "string" },`. No
`required` array change (`layout.inference.required` stays `["enabled"]`, matching
`ranker.inference.required`, which also does not require `pvc`).

### 2. `helm/` mirror — manual, no regen tooling

Confirmed: `diff src/groundx/values.schema.json helm/values.schema.json` currently reports no
differences (both 1929 lines). `src/groundx/` is authoritative, and `helm/` is a manual mirror for
the published chart surface. Because there is no in-repo generator, the source edit must be synced
into `helm/values.schema.json` in the same change. **Decision:** hand-mirror the identical `pvc`
block into `helm/values.schema.json` at the structurally identical location, then verify
byte-identity with `diff` (see tasks.md) rather than relying on tooling that does not exist.

### 3. No new compatibility mechanism needed — this is additive, not breaking

This touchpoint is **schema-only** and has no cross-service producer/consumer relationship
(`contract_roles: INDEPENDENT`) — it is a single Helm chart's own values contract. Classifying the
change:
- **Before:** any values file setting `layout.inference.pvc` is universally rejected (schema
  validation failure) — no existing install can be relying on that key being accepted, since it
  was never legal.
- **After:** the same key becomes legal (opt-in, only exercised if an operator sets it).
- This is **strictly additive** for every existing values file that does *not* set
  `layout.inference.pvc` — nothing about their validation or rendering changes. No values file
  in `src/groundx/values/*.yaml` (checked: none of the example env values files set
  `layout.inference.pvc`) is affected. No versioned API field, feature flag, or expand/migrate
  schema-change path is warranted — this is a same-release schema widening of a single chart
  version already in flight (`0.2.7`, unpublished), not a rollout across already-deployed
  chart versions.

### 4. No ADR warranted

This is a single-line, verbatim, self-evidently-correct schema mirror (copy an existing sibling
block) with no open design question, no new mechanism, and no cross-service coordination — it does
not meet the bar for an ADR (no alternative was considered or rejected; the ticket, the proposal,
and this design already capture the full rationale).

## Risks / Trade-offs

- **`helm/` drift risk (pre-existing, not introduced by this change):** because the mirror is
  manual and unenforced, a future edit to `src/groundx/values.schema.json` that forgets to touch
  `helm/values.schema.json` would silently reintroduce drift. This change does not fix that gap;
  it follows the existing (only available) convention and adds an explicit verify-step
  (byte-identity `diff`) so at least *this* change ships in sync.
- **Blast radius stays additive:** `layout.inference` keeps `additionalProperties: false`, so this
  change permits exactly one new key (`pvc`) and does not loosen validation for anything else —
  confirmed by the spec's negative scenario (an unrelated unrecognized key under
  `layout.inference` is still rejected).
- **Rollout:** no ordering/canary concern — this ships as part of the normal `0.2.7` chart
  release; it does not require a stateful-resource migration or zero-downtime sequencing, since no
  running install can already be setting `layout.inference.pvc` (previously illegal). Operators who
  want to actually cut `layout-inference` over to EFS-RWX (the followup, out of scope here) will
  do so via their own `helm upgrade` once `0.2.7` is available, at a time of their choosing.
