## Goals / Non-Goals

**Goals:**
- Let the chart render a k8s `terminationGracePeriodSeconds` and a derived application
  `drainSeconds` for any of the five Go queue-service pods, opt-in per service via
  `replicas.gracePeriod`, with zero change to any install that never sets it.
- Keep `src/groundx/` and `helm/` byte-identical for the three touched files.

**Non-Goals (per proposal + source-of-truth — do not build these here):**
- Setting a chart-default `gracePeriod` value for any service.
- Any non-`summaryClient` values enablement, DLQ, HPA `scaleDown` tuning, or raising the SQS
  visibility timeout.
- Any change to cashbot-go — the `drainSeconds-config` touchpoint is FINALIZED at cashbot-go
  commit `f82196e4`; this design treats its shape as given.
- Concrete sizing (`gracePeriod: 900`/`drainSeconds: 870`) — that is the private FraudX
  values override, a separate repo, out of scope here.

## Decisions

**Invariant** (this change applies the same shaped edit at 5+ sites — schema, `golang.yaml`,
and `config-yaml.yaml` — so the sweep must preserve one property, not just satisfy the diff
token at each site): *a service's rendered grace-period-derived fields (`terminationGracePeriodSeconds`,
`drainSeconds`) may differ from today's output only when that exact service's own
`replicas.gracePeriod` is present in values — never when a different service sets it, and
never for a service that leaves it unset.* `spec.md`'s "Sweep consistency" requirement
carries the two required scenarios (catches / must-not-block) that hold this invariant to
the five parallel `config-yaml.yaml` edits, which are the highest-risk site because they are
five separately-authored literal stanzas, not a loop — a copy-paste mistake there is exactly
how one service's setting could leak into a sibling's block.

1. **Schema — add `gracePeriod: { "type": "integer" }` to all five Go queue-service
   `replicas` blocks**, keeping `additionalProperties: false`. Precedent: the `extract.*`
   sub-service `replicas` blocks already carry `gracePeriod` the same way (e.g.
   `values.schema.json:1424`) — same key name, same type, same position (alongside
   `desired`/`max`/`min`, alphabetically ordered). No `minimum`/`maximum` constraint is added
   because the existing `extract.*.replicas.gracePeriod` precedent has none either, and this
   proposal does not ask for one.
   - Alternative considered: a chart-level default via JSON Schema `default`. Rejected —
     the proposal's whole no-op guarantee for ~20 existing services depends on the key being
     *absent*, not defaulted; a schema default would render the field for every install on
     the next `helm template` pass even without the operator setting it.

2. **`golang.yaml` — copy the `celery.yaml:73-76` guard pattern** (`$rp` is already read as
   the per-service replicas map at `golang.yaml:23`):
   ```
   {{- if and $rp (hasKey $rp "gracePeriod") }}
         terminationGracePeriodSeconds: {{ get $rp "gracePeriod" }}
   {{- end }}
   ```
   Placed at the top of the pod `spec:` block, mirroring `celery.yaml`'s placement exactly.
   - Difference from the `celery.yaml` precedent: `celery.yaml` has an `else if eq $mapPrefix
     "extract"` branch that defaults unset `gracePeriod` to `900` for `extract` services.
     That default is **not** carried over here — no default was requested for the Go queue
     services (Non-Goals), and `golang.yaml` has no `$mapPrefix`-equivalent per-family
     variable to gate a default on even if one were wanted. Omitting the `else` branch is a
     deliberate scope choice, not an oversight.
   - Because `golang.yaml`'s `range` loops over all ~20 shared Go services in one pass, this
     guard applies uniformly to every one of them — a service other than the five Go queue
     services would also get the render if its values ever set `gracePeriod` (none do
     today; none are asked to). This is intentional per the proposal ("the guard means only
     a service whose values set `gracePeriod` is affected") and matches the invariant above:
     presence-gated, not name-gated.

3. **`config-yaml.yaml` — five parallel edits, each keyed to its own service's replicas
   dict.** `config-yaml.yaml` has no per-service `range` for this section (`$svcs`, defined
   at line 1, only gates the section as a whole); each of the five blocks
   (`preProcessFileServer`/`processFileServer`/`queueFileServer`/`summaryServer`/
   `uploadFileServer`) is edited independently, computing its own replicas dict via the
   service's existing helper (`groundx.preProcess.replicas`, `groundx.process.replicas`,
   `groundx.queue.replicas`, `groundx.summaryClient.replicas`, `groundx.upload.replicas` —
   each already defined in `_helpers/app/*.tpl` and already used the same way by
   `golang.yaml`'s loop), for example:
   ```
       preProcessFileServer:
         baseURL: {{ include "groundx.preProcess.serviceUrl" . }}
   {{- $ppRep := (include "groundx.preProcess.replicas" . | fromYaml) }}
   {{- if hasKey $ppRep "gracePeriod" }}
         drainSeconds: {{ int (max 1 (sub (int (get $ppRep "gracePeriod")) 30)) }}
   {{- end }}
         maxConcurrent: {{ include "groundx.preProcess.queueSize" . }}
         port: {{ include "groundx.preProcess.containerPort" . }}
         serviceName: {{ include "groundx.preProcess.serviceName" . }}
   ```
   repeated for the other four blocks with each service's own helper name and local variable
   name (e.g. `$pRep`/`$qRep`/`$scRep`/`$upRep`) — deliberately **not** a shared variable
   name reused across blocks, precisely to avoid the invariant-violating copy-paste risk the
   "Sweep consistency" spec requirement calls out.
   - `drainSeconds` is placed alphabetically between `baseURL` and `maxConcurrent`, matching
     this file's existing alphabetical key ordering within each block.
   - Margin derivation follows the exact expression shape already used in
     `extract-supervisord-conf.yaml:15-16` (`int (max 1 (sub $gracePeriod 30))`), except
     **without** that file's `dig "gracePeriod" 900 $replicas` default-900 fallback — here
     the whole expression is inside the `hasKey` guard, so it only evaluates when
     `gracePeriod` is actually present (consistent with the no-default Non-Goal above).
   - Alternative considered: hooking into the `$svcs`-gated section-level condition instead
     of five independent per-block guards. Rejected — confirmed by reading the file that
     `$svcs` only gates the section as a whole (line 71), not per-service; there is no
     existing per-service loop to attach to, so five independent edits is the only shape
     that matches the file's actual structure.

4. **CONSUMER/HYBRID tolerant-reader check — not applicable in this direction.** The
   `drainSeconds-config` touchpoint is one-directional: this chart *writes* the
   `drainSeconds` value into `config-yaml.yaml`; it does not parse or receive anything back
   from cashbot-go. The tolerant-reader property that matters for this touchpoint (an old
   cashbot-go binary's non-strict `yaml.v2` decode ignoring an unrecognized `drainSeconds`
   key) is confirmed in `contract.md` as a property of the **producer's** parser, not
   something this chart needs to implement. This design does not add a tolerant-reader
   mechanism on the chart side because there is nothing here that reads an upstream shape.

5. **No ADR.** This is an additive schema property plus two template edits that copy two
   already-established patterns in this same chart (`celery.yaml`'s grace-period guard,
   `extract-supervisord-conf.yaml`'s margin derivation) — not a new architectural pattern, a
   new dependency, or a hard-to-reverse decision. Reverting is a plain chart revert. No
   `docs/adr/` entry is warranted.

6. **`context:` in `openspec/config.yaml` — no update needed.** The existing context block
   already documents the `src/groundx` ↔ `helm/` mirror discipline, the snapshot-as-CI-gate
   pattern, and the exact schema line ranges for the affected blocks; nothing discovered
   while authoring this design was missing from it.

## Risks / Trade-offs

- **[Risk] Copy-paste error across the five `config-yaml.yaml` stanzas leaks one service's
  `gracePeriod` into a sibling's block or omits a block entirely** → Mitigation: the
  "Sweep consistency" spec requirement's `catches`/`must-not-block` scenarios are committed
  tests (helm-unittest `set:` + `documentSelector` assertions, one per block), not design
  prose; a leak or omission fails CI.
- **[Risk] `helm/` mirror drifts from `src/groundx/`** → Mitigation: tasks.md includes an
  explicit `diff` check on the three touched file pairs as part of verify; the repo has no
  automated drift check otherwise (a known, pre-existing gap noted in `AGENTS.md`).
- **[Risk] A non-integer or negative `gracePeriod` reaches the template despite the schema**
  (e.g. a values file that bypasses `helm template --validate` some other way) → Mitigation:
  the template wraps the value in `int (...)` before `sub`, matching the
  `extract-supervisord-conf.yaml` precedent, and the `max 1` floor prevents a negative
  `drainSeconds`; schema validation remains the primary guard (see the schema requirement's
  reject scenarios).
- **[Risk] Roll-forward behavior change once an install sets `gracePeriod`**: a pod that
  crashes instead of draining cleanly now takes up to the configured `gracePeriod` (bounded)
  to be force-killed on scale-down/rollout, instead of today's implicit 30s. This is the
  intended trade documented in the proposal's Blast Radius section, not a defect; it only
  applies to installs that opt in.

## Migration Plan

- No data migration, no stateful-resource change (per proposal's Blast Radius section) —
  this only changes a Deployment spec field and a ConfigMap value.
- Rollout: `src/groundx/` edits (schema → `golang.yaml` → `config-yaml.yaml`) → sync into
  `helm/` → regenerate `helm-unittest` snapshots (`helm unittest -u src/groundx`) → verify
  (`helm lint`, `helm unittest`, `helm template` render check, mirror `diff`). Any install
  order relative to the paired cashbot-go image is safe (Additive touchpoint; see the
  backward-compatibility spec scenario) — this repo's chart release does not need to be
  gated on the cashbot-go image's release.
- Rollback: revert the chart change (or, for FraudX, drop the values override that sets
  `gracePeriod`). Since no `gracePeriod` renders identically to today, rollback is a plain
  `helm upgrade` to the prior chart version/values with no data to unwind.

## Amendments

### 2026-08-12 — `minimum: 1` added to the five Go queue-service `gracePeriod` schema entries

Decision 1 above ("No `minimum`/`maximum` constraint is added … this proposal does not ask
for one") is **superseded**. A review advisory identified that a non-positive `gracePeriod`
(`0` or negative) pairs incoherently with the rendered fields: `terminationGracePeriodSeconds:
0` forces an immediate kill (no drain window at all) while the same value's derived
`drainSeconds` floors to `1` (per the `max 1 (sub gracePeriod 30)` expression) — the pod is
killed before the config value it was given even has meaning. `values.schema.json` was
changed to add `"minimum": 1` to `gracePeriod` on the five Go queue-service `replicas` blocks
(`summaryClient`/`process`/`upload`/`queue`/`preProcess`), rejecting `0` and negative values at
schema validation.

This intentionally diverges from the `extract.*` `replicas.gracePeriod` precedent cited in
Decision 1, which has no `minimum` and remains unguarded. `extract.*` is a separate service
family, out of this proposal's scope, and its existing unguarded `gracePeriod` is a
pre-existing condition, not something this change introduces or fixes. Bringing `extract.*`
into alignment is left for a possible follow-up guard-completeness ticket, not filed as part
of this change.

The promoted spec (`openspec/specs/queue-service-grace-period/spec.md`, "Schema accepts
`gracePeriod` as an optional integer ≥ 1, strict otherwise" requirement) was updated to match
and now carries a reject-non-positive scenario.
