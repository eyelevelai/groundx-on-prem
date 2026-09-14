Builds on the accepted `proposal.md`: this is a chart-only, config-surface change making
liveness/readiness probe timing Helm-configurable for the five API-pod Deployments, with defaults
that are at least as forgiving as today's implicit behavior.

## Goals / Non-Goals

**Goals:**
- Make `timeoutSeconds` (liveness and readiness) and readiness `failureThreshold` Helm values for
  all five API-pod Deployments (`layout`, `extract`, `ranker`, `summary`, `workspace`).
- Ship defaults that are strictly at-least-as-forgiving as today's implicit Kubernetes behavior,
  so no environment newly fails a probe it was passing before.
- Reject an undeclared or malformed probe-timing key at Helm's values-schema step, for all five
  services, matching this chart's existing `additionalProperties: false` convention.
- Keep `src/groundx` and its manual `helm/` mirror in sync for these fields.

**Non-Goals:**
- Fixing the FRA-145 production incident itself. The incident's root cause (blocking Redis I/O on
  the event loop starving the `/health` handler, per `source-of-truth.md`'s Comment-3 carve-out) is
  fixed by the paired `ai-server` change, not here.
- Raising `layout.api.replicas.max` or any `workers`/`threads`/`resources` value. Per
  `source-of-truth.md`, the FraudX team has already raised `replicas.max`, and Comment 3 disproves
  the 32-slot ceiling as the mechanism — re-proposing either is explicitly out of scope.
- Changing the `/health` endpoint's path, method, or response shape. That contract is unchanged on
  both sides of this touchpoint (see `specs/api-probe-timing/spec.md`'s backward-compatibility
  requirement).
- Editing `groundx-helm-charts` `applications/prod/groundx/values.yaml`. That repo is outside this
  workspace; this change only adds the knob, it does not turn it on in production.

## Decisions

### Shipped defaults, and which ones change effective behavior on `helm upgrade`

| Value | Shipped default | Changes existing deployments on upgrade? |
| --- | --- | --- |
| liveness `timeoutSeconds` | `3` | **Yes.** Every existing deployment currently runs Kubernetes' implicit `1`-second default (confirmed: `grep -rn timeoutSeconds src/groundx/templates/` returns no matches anywhere in this chart, so this field is genuinely new, not previously set some other way). Raising it to `3` strictly widens the passing window: a probe that was passing at 1s still passes at 3s, so this can only turn a failing probe into a passing one, never the reverse. |
| readiness `timeoutSeconds` | `3` | **Yes**, same reasoning and same direction as liveness. |
| readiness `failureThreshold` | `3` | **No.** `src/groundx/templates/app/api.yaml:151` (readiness block) has never set this field, so it already inherits Kubernetes' implicit default of `3`. Writing `3` explicitly reproduces that exact number — this is a documentation/schema change on this axis, not a behavior change. |
| liveness `failureThreshold` | `12` (unchanged) | **No.** Already explicit at `src/groundx/templates/app/api.yaml:146`; this change does not touch it. |

### Values schema shape: nested `api.probe.{liveness,readiness}`, not flat keys

The existing `*.api` blocks use flat scalar keys for simple, unambiguous knobs (`threads`,
`timeout`, `workers` — see `src/groundx/templates/_helpers/app/layout-api.tpl:178-193`). A flat
`timeoutSeconds` key cannot be reused here: `timeout` already exists on every one of the five `api`
blocks and means the gunicorn worker timeout in seconds, not a probe timeout, and a flat
`timeoutSeconds` would still be ambiguous between the two probes. Two structurally sound options
were available: flat prefixed keys (`livenessTimeoutSeconds`, `readinessTimeoutSeconds`,
`readinessFailureThreshold`) or a nested `probe: { liveness: {...}, readiness: {...} }` object
mirroring Kubernetes' own `livenessProbe`/`readinessProbe` shape.

**Decision: nested.** This chart's schema already nests a values sub-object whenever the
underlying Kubernetes shape has more than one related field under one concept (e.g. `ingress`,
`serviceAccount`, `replicas` all nest — see `src/groundx/values.schema.json`'s `*.api.ingress` /
`*.api.serviceAccount` / `*.api.replicas` blocks). Two probes each carrying multiple named fields
is exactly that shape, and nesting also gives each probe its own `additionalProperties: false`
boundary (see the schema-rejection requirement in `spec.md`) without inventing a naming prefix
convention this chart doesn't otherwise use. Pinning this now (rather than leaving it open) is
what unblocks `tasks.md`:

```yaml
<service>:
  api:
    probe:
      liveness:
        timeoutSeconds: 3
      readiness:
        timeoutSeconds: 3
        failureThreshold: 3
```

Each of the three nesting levels (`probe`, `probe.liveness`, `probe.readiness`) gets its own
`additionalProperties: false` in `values.schema.json`, matching this chart's existing strict
convention on nested value objects.

### Why `30` was not copied from `inference.yaml`'s readiness `failureThreshold`

`src/groundx/templates/app/inference.yaml:224-249` is the chart's only other explicit readiness
probe and its only explicit readiness `failureThreshold` (`30`) anywhere in the chart. It was not
copied here because it is not a compatible precedent for this template's cadence:

- It pairs with `periodSeconds: 15` (`inference.yaml:249`), not this template's `periodSeconds: 30`
  (`api.yaml:154`). `failureThreshold x periodSeconds` is the real "how long before ejection"
  number, not `failureThreshold` alone.
- It is the `httpGet` branch that runs when the container is not the exec-checked inference process
  (`inference.yaml:232` `{{- else }}`) — i.e. a separate health-checking code path from the
  `ps aux`-based exec probes at `inference.yaml:216-231`, calling its own `/alive` and `/health`
  paths rather than sharing this template's process.
- Copying `30` at this template's `periodSeconds: 30` would mean `30 x 30s = 900s` (15 minutes)
  before a dead API pod is pulled from readiness — an unacceptably long window for a
  request-serving API tier under the sustained-concurrency conditions FRA-145 describes. The
  chosen `3` at `periodSeconds: 30` reproduces today's `3 x 30s = 90s` window exactly (see the
  "no behavior change on this axis" row above).

### `timeoutSeconds` is new to this chart, not a pre-existing-elsewhere value being extended

`grep -rn "timeoutSeconds" src/groundx/templates/` returns no matches. Every pod chart-wide
currently runs Kubernetes' built-in `1`-second probe timeout, including the `inference.yaml`
probes discussed above. This change makes the five API pods the first in this chart to set the
field explicitly; it is not extending an existing convention.

### This chart change ships a knob, not a production behavior change

The values consumed by the actual production deployment live in `groundx-helm-charts`
`applications/prod/groundx/values.yaml`, a repo outside this workspace that this change cannot
read or edit. Merging this change does not, by itself, move production's effective probe timing —
that requires a separate edit to that external repo (or a later chart-version bump, on that repo's
own cadence). The incident's actual root cause is fixed entirely by the paired `ai-server` change;
this chart change only removes the artificially tight ceiling so that fix is not undermined by an
unrelated probe-timing default once production's values are updated to consume it.

## Risks / Trade-offs

- [Risk] A `helm upgrade` on an environment with no explicit probe-timing override silently
  changes liveness/readiness `timeoutSeconds` for every one of the five API services at once.
  → Mitigation: the direction is strictly more forgiving (see the defaults table above) — there is
  no scenario in which raising a timeout newly fails a probe that was passing before, and an
  environment that wants the old numbers back can set them explicitly via the new override.
- [Risk] `helm/` and `src/groundx` drift on these new fields, since this repo has no regen script
  or automated drift guard (`CLAUDE.md` context, "KNOWN GAPS"). → Mitigation: `tasks.md` includes a
  dedicated drift-check task comparing rendered output between the two trees for these fields, and
  the manual sync is done in the same change rather than deferred.
- [Risk] A future edit to one service's `*.api` schema block could copy the `probe` sub-schema
  without also copying its `additionalProperties: false` boundaries, silently reopening the
  undeclared-key gap this change closes. → Mitigation: the schema-rejection tests in `tasks.md`
  cover all five blocks individually, not just one, so a future regression in any one block fails
  its own test.

## Migration Plan

- No stateful or data resource is touched; this is probe-timing configuration only.
- Deploy: a normal `helm upgrade` picks up the new defaults immediately for every environment on
  this chart version, whether or not that environment's values file mentions the new keys (they
  are chart defaults, not opt-in flags). No ordering constraint against the paired `ai-server`
  change — the `/health` touchpoint (path, method, response shape) is unchanged on both sides, so
  either may deploy first (see `specs/api-probe-timing/spec.md`'s backward-compatibility
  requirement).
- Rollback: a `helm rollback` to the prior release, or, without a full chart rollback, an explicit
  `timeoutSeconds`/`failureThreshold` override in the environment's own values file restoring the
  prior effective numbers (`1`/implicit for `timeoutSeconds`, `3` for readiness
  `failureThreshold` — already the same number, so no override needed on that axis).
- This chart change alone does not move production's effective probe timing (see the decision
  above) — a human still edits `groundx-helm-charts` `applications/prod/groundx/values.yaml`
  separately to activate these defaults in production, on that repo's own change process.

## Open Questions

None. The shipped defaults, the values-schema shape, the two upgrade-behavior determinations, and
the affected-file list are fully specified above; no `superpowers:brainstorming` session is needed.
