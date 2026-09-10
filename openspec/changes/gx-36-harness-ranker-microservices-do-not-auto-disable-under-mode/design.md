# Design, GX-36: Restore ingest-only auto-disable for the ranker microservices

Grounding: `proposal.md` (approved) covers the blast radius, rollout, and destructive-upgrade
disclosure in full — this document does not restate them. Everything below was verified against
`origin/0.2.7` tip `b8e57f2d`, helm v3.19.0 (`GX_ON_PREM_HELM=/Users/nitin/.local/bin/helm-v3.19.0`;
the PATH `helm` in this workspace is v4.2.2 and unusable for this chart).

## Goals / Non-Goals

**Goals:**
- Restore the pre-`e4319321` mode-first branch order in `groundx.ranker.api.create`
  (`src/groundx/templates/_helpers/app/ranker-api.tpl:13-24`) and
  `groundx.ranker.inference.create` (`ranker-inference.tpl:13-24`), mirrored byte-for-byte into
  `helm/templates/_helpers/app/`.
- Regenerate every snapshot block whose content is a mechanical consequence of that reorder —
  proven below to be five files, not the three the proposal named — with the diff scoped to only
  the mode-`ingest` fixture blocks.
- Add permanent `mode: ingest` resource-name assertions to `src/groundx/tests/ranker_test.yaml`.
- Add a dual-surface ingest render guard to `.build/bin/validate-helm.sh`, with its classification
  logic extracted to `.build/bin/verify-ingest-render.py` and committed known-bad/known-good
  fixtures at `.build/tests/test_verify_ingest_render.py` (round-2).
- Annotate the now-inert `cluster.nodeLabels.gpuRanker` entry in `values/chainguard/values.yaml`
  (+ mirror) rather than removing it, leaving `values.schema.json` untouched.
- Round-2: gate `groundx.ranker.inference.busyWindowSeconds` on `.create` — the one sibling in its
  family that ignored it — regenerating a sixth snapshot file (`ranker_test.yaml.snap`).

**Non-Goals:**
- `origin/main` (chart 0.2.6 line) — not touched, per explicit direction (decomposition A2).
- `_helpers/app/ingress.tpl:16` not gating on `.create` — pre-existing, shared with
  extract/layout/summary api ingress, out of scope.
- Harness docs (`deployment-modes.md`) — no edit needed; its claims become true once this ships.
- `values/extract/values.yaml` / `values.oai.yaml` — already correct (fully commented-out
  `nodeLabels:` example block); not touched.

## Decisions

**Invariant** (this change modifies a CI gate — `.build/bin/validate-helm.sh` — so states the
property it must hold, not the token that stands in for it): *under `mode: ingest`, none of the
seven ranker objects — the `ranker-api` / `ranker-inference` Deployments, the `ranker-api`
Service, the `ranker-model` PersistentVolumeClaim, the `ranker-config-py-map` Secret, and the
`ranker-gunicorn-conf-py-map` / `ranker-inference-supervisord-conf-map` ConfigMaps — and no
`eyelevel-gpu-ranker` node-affinity/toleration reference, may render from either chart surface,
regardless of an explicit `ranker.*.enabled: true` — while every other workload that mode leaves
enabled still renders.* A gate that only checks "`ranker.*.enabled: false` is set" would pass the
pre-`e4319321` regression itself (the dead-code branch never reads that field once `hasKey` wins);
a gate that zeroes the whole `api.yaml`/`inference.yaml` render would falsely block
`extract`/`layout`/`summary` workloads that must keep rendering under `mode: ingest`. Both failure
shapes are asserted below.

- **Fix shape: mode-first ordering.** Test `groundx.ingestOnly` before `hasKey $in "enabled"` in
  both `.create` helpers, matching the chart's own convention preserved in
  `groundx.search.create` (`src/groundx/templates/_helpers/services/search.tpl:12-16`). The
  ticket's alternative (delete the `enabled: true` defaults) is not viable:
  `values.schema.json` marks `ranker.api`/`ranker.inference` `"required": ["enabled"]` with
  `additionalProperties: false` — removing the default fails schema validation. Under `mode:
  ingest`, mode wins unconditionally over an explicit `ranker.*.enabled: true` — verified this is
  also true of `groundx.search.create` today, so this is a restoration of an existing pattern, not
  a new one.
- **HPA is a downstream consequence, not a separate code change.** `resources/hpa.yaml` renders
  per-service via `groundx.ranker.api.hpa` / `groundx.ranker.inference.hpa`
  (`ranker-api.tpl:120-137`, `ranker-inference.tpl:103-121`), both of which already set
  `$enabled := false` whenever `$ic := include "groundx.ranker.*.create"` is not `"true"`. No HPA
  template edit is needed; a `cluster.hpa: true` + `mode: ingest` test case proves it.
- **Assertion mechanism: `containsDocument` with `any: true`, not `hasDocuments: count`.**
  Verified empirically that `helm-unittest` 1.1.2's `containsDocument` assertion, applied without
  `any: true` against a multi-document template render, evaluates **per document index** rather
  than as an existence check across the whole set — every non-matching index reports a spurious
  failure. Adding `any: true` (documented as "ignores any other documents") makes it the correct
  existential check; combined with `not: true` it asserts "no document in this render matches
  {kind, apiVersion, name}" without needing a total document count, satisfying the "assert by
  resource name" requirement. `tests/files/values.extract.ingest.yaml` was used unmodified (chart
  `ranker.*.enabled: true` defaults stay in effect) rather than `values.disabled.yaml`, which
  already sets both ranker keys `false` and would prove nothing.
- **Snapshot regen scope is five files, not three — corrects the proposal's Impact list.**
  `templates/app/golang.yaml:59` and `templates/app/metrics.yaml:119` hash the **shared**
  `resources/config-yaml.yaml` render into their `config-hash` annotation
  (`{{ include (print $.Template.BasePath "/resources/config-yaml.yaml") . | sha256sum }}`), and
  that shared file's content includes ranker's busy-metric entries. Once `ranker.inference.create`
  flips to `false` under `mode: ingest`, those entries drop out of `config-yaml.yaml`, changing its
  hash, which changes the `config-hash` annotation on every `golang.yaml`/`metrics.yaml` workload
  rendered under an already-`mode: ingest` fixture (`extract:`, `extract.ingest:`, `extract.oai:`
  cases) — even though those workloads (e.g. the `groundx` API) have nothing to do with ranker.
  `api.yaml`/`celery.yaml`/`inference.yaml` hash a **per-service** `<mapPrefix>-config-py.yaml`
  instead, so non-ranker services in those three files are unaffected. Verified by a scoped
  `helm unittest -u -f 'tests/golang_test.yaml' -f 'tests/metrics_test.yaml' src/groundx`: the
  resulting diff touches only `config-hash` lines inside the `extract:`/`extract.ingest:`/
  `extract.oai:` blocks of `golang_test.yaml.snap` and `metrics_test.yaml.snap` — nothing else.
  **Corrected constraint:** the regenerated diff across all five snapshot files
  (`api`, `inference`, `resources`, `golang`, `metrics`) must touch only labels prefixed
  `extract:`, `extract.ingest:`, or `extract.oai:`; any other label changing is a defect. This
  supersedes the proposal's narrower "only the three `extract.ingest:*` blocks" wording — the
  `mode: all` byte-identical intent is unchanged, only the enumeration of which fixture families
  set `mode: ingest` was incomplete (`values/extract/values.yaml` and `values.oai.yaml` also do,
  and both feed `api`/`inference`/`resources`/`golang`/`metrics` suites).
- **Round-2: `groundx.ranker.inference.busyWindowSeconds` was the one sibling in its family not
  gated on `.create` — a sixth snapshot file, not a widening of the five above.**
  `.threshold` and `.throughput` both derive their rendered value from `groundx.ranker.inference.create`
  (they collapse when the workload doesn't render); `busyWindowSeconds` gated only on the HPA flag
  (`cluster.hpa`) and never checked `.create`, so under `mode: ingest` + `cluster.hpa: true` it kept
  emitting a `ranker-inference` entry into `metrics.inference`'s `config-yaml.yaml` even though no
  `ranker-inference` Deployment rendered — a metrics component pointed at a workload this change
  removes. Fixed by gating `busyWindowSeconds` on `.create` too, matching its siblings. This is a
  distinct **correctness** fix independent of `mode` (it also corrects a `mode: all` render where
  `ranker.inference` is individually disabled — `ranker_test.yaml`'s `cache override: ranker api`
  case), not a widening of the mode-first-ordering fix, so its `ranker_test.yaml.snap` diff is
  scoped to that one label rather than falling under the `extract:`/`extract.ingest:`/`extract.oai:`
  constraint above (see `spec.md`'s "Exception, independent of `mode`" note and task 3.2's own
  check). Task 3.1's snapshot count is six files, not five, once this is included.
- **A full-suite `helm unittest -u src/groundx` is unsafe and must not be used.** Verified: even
  with zero template changes, a bare full-suite `-u` regen churns 9-10 snapshot files (drops
  `matchSnapshot` labels for empty renders — e.g. `'disabled: api':` — and reorders unrelated
  labels), because `helm-unittest` 1.1.2's snapshot writer both drops the label line for a
  zero-document render and does not preserve this repo's required alphabetical label ordering
  (`.build/bin/verify-helm-snapshots.py` enforces both). Regen must be scoped with
  `-f 'tests/<file>_test.yaml'` to exactly the five affected files, and the dropped empty labels
  (`'disabled: api'`, `'disabled: inference'`, `'workspace-enabled: inference'`,
  `'disabled: resources'`, `'disabled: golang'`, `'workspace-enabled: golang'` — the exact set
  `verify-helm-snapshots.py`'s `REQUIRED_EMPTY_LABELS` already names for these files) must be
  manually restored in sorted position afterward. `.build/bin/verify-helm-snapshots.py` (already
  in the CI gate) is the check that the restoration is complete and correctly ordered.
- **Test placement: `src/groundx/tests/ranker_test.yaml` only.** No `helm/tests` tree exists; CI
  runs `helm unittest` against `src/groundx` alone; `helm/.helmignore:15` excludes `tests/` from
  the package, so a mirrored test would never execute. `helm/`'s surface is covered instead by the
  `.build/bin/validate-helm.sh` guard below, which is the only mechanism that ever exercises it.
- **`.build/bin/validate-helm.sh` guard: structural per-document parsing, not a flat grep.**
  `helm template <chart> --set mode=ingest` output is split on `^---$` document boundaries; each
  document's `kind:` and the metadata `  name:` line (2-space indent, quote-tolerant) are matched
  per document, not via a single flat-text grep — avoiding both the false-negative a bare
  `grep -q 'name: ranker-api'` would produce against a `Service`'s quoted `name: "ranker-api"`
  form and the false-positive a substring match could produce against an unrelated field.
  `pyyaml` is not a repo dependency (`python3 -c "import yaml"` fails on the environment's bare
  `python3`, and the rest of `validate-helm.sh`'s embedded Python only uses `json`/stdlib), so a
  structural per-document regex split was used instead of introducing a new toolchain dependency
  for this one check. **Verified all four required guard properties** (Guard change class, fail
  closed / structural / fixtures):
  - **catches** — run against the unfixed templates: `src/groundx: mode=ingest must not render
    Deployment=['ranker-api'].`, exit 1 (this is the shipped guard's kind-qualified output, run
    against a single-Deployment probe; a render carrying multiple forbidden documents reports one
    `<Kind>=[...]` segment per violated kind, joined with `; `).
  - **dual-surface** — fixed only `src/groundx`, left `helm/` unfixed: guard passed `src/groundx`
    and failed on `helm` with the same message, proving both surfaces are independently checked
    (catches a mirror-sync omission, the repo's own named hazard).
  - **must not block** — fixed both surfaces, then synthetically forced
    `groundx.layout.api.create` to always return `false` (simulating an over-blocking
    implementation): guard reported `src/groundx: mode=ingest must still render sibling services
    ['layout-api']; a guard that also drops these is over-blocking, not fixed.`, exit 1 — a
    distinct message from the forbidden-render case, proving the guard would catch the
    `hasDocuments: count: 0`-style over-block the orchestrator's brief warned against.
  - **green** — both surfaces fixed, siblings intact: the section prints only its own header
    (`==> Verifying ranker microservices do not render under ingest-only mode`) and exits 0 with
    no further output — `verify-ingest-render.py` prints nothing on success, so there is no
    literal "pass" string to quote.
- **Round-2: the guard's classification logic is extracted into `.build/bin/verify-ingest-render.py`
  with committed fixtures at `.build/tests/test_verify_ingest_render.py`, mirroring the existing
  `.build/bin/verify-helm-snapshots.py` / `.build/tests/test_verify_helm_snapshots.py` pattern
  already in this gate.** The guard was push-gating with its must-reject behavior proven only by
  ad-hoc render, not a committed counterexample. `validate-helm.sh` now runs the fixture test ahead
  of the guard, same as the snapshot-guard section. Fixtures use small synthetic multi-document YAML,
  not full chart renders. Provenance only — the classification logic and its per-category
  short-circuit behavior are unchanged; re-verified against a reconstructed pre-fix render
  (`b8e57f2d`) on both chart surfaces (exit 1, same messages) and against head on both surfaces
  (exit 0).
- **Round-3: mutation testing showed the round-2 fixture set proved only 3 of the 7 forbidden
  names — one fixture per name is now required, not one per kind.** Deleting a whole
  `FORBIDDEN_BY_KIND` entry (`Service`, `Secret`, or `ConfigMap`) or dropping `ranker-inference`
  from the `Deployment` set left all committed fixtures green, because the round-2 set covered
  only `Deployment=['ranker-api']` and `PersistentVolumeClaim=['ranker-model']` plus the
  over-block and node-label arms. Added one fixture per previously-uncovered name —
  `Deployment=['ranker-inference']`, `Service=['ranker-api']`,
  `Secret=['ranker-config-py-map']`, `ConfigMap=['ranker-gunicorn-conf-py-map']`, and
  `ConfigMap=['ranker-inference-supervisord-conf-map']` — each asserting the exact per-kind
  violation message. Re-verified by mutation: deleting any of the five `FORBIDDEN_BY_KIND`
  entries, or removing `ranker-inference` from the `Deployment` set alone, now fails the suite;
  restoring the entry returns it to green.
- **`cluster.nodeLabels.gpuRanker` is annotated in place, not removed; `values.schema.json` is
  untouched.** `values/chainguard/values.yaml` sets `cluster.nodeLabels.gpuRanker:
  eyelevel-gpu-ranker` alongside four still-needed labels (the file also sets `mode: ingest`, so
  `layout`/`summary`/`extract`/`workspace` still render and still need their node labels).
  `groundx.node.gpuRanker` has exactly one consumer in the chart,
  `_helpers/app/ranker-inference.tpl:4`, which stops evaluating once this change lands, so the
  value is genuinely inert in this preset.

  Deleting it is not possible on its own. `values.schema.json` marks all five `nodeLabels` keys
  `"required"` with `additionalProperties: false`; verified that removing only the `gpuRanker`
  line makes `helm lint` fail with
  `[ERROR] values.yaml: - at '/cluster/nodeLabels': missing property 'gpuRanker'`. Removing the
  whole `nodeLabels:` block instead is not viable either: the other four labels differ from their
  schema defaults (`cpuMemory: eyelevel-cpu` vs. default `eyelevel-cpu-memory`), so dropping the
  block would silently retarget node selectors for the still-rendering workloads in that file.

  That leaves two options: relax the schema so the key may be omitted, or keep the key and say
  why it is inert. **Resolution: keep it and annotate it.** Relaxing a validation rule to enable a
  cosmetic cleanup is the worse trade, and it buys less: a deletion leaves a reader nothing, while
  the comment states the reason the key is present but unused. It also matches how
  `values/extract/values.yaml:18` and `values.oai.yaml:18` already communicate the identical fact
  about this same label. Verified that the annotated file lints clean on both chart surfaces and
  that `values.schema.json` is byte-unchanged.

  The relaxation alternative was implemented first and reverted at the human gate. It was proven
  safe (strictly widening, every values file that sets `gpuRanker` stays valid, and
  `groundx.node.gpuRanker` carries an `eyelevel-gpu-ranker` fallback so no render changes), so it
  remains available if the inert key is later judged worse than the schema change.

## Risks / Trade-offs

- **[Risk] The destructive-upgrade impact on existing `mode: ingest` installs** (deletes the seven
  ranker objects — see `proposal.md` Blast radius for the full inventory and the volume-reclaim
  qualification — on the first upgrade past published 0.2.6) →
  **Mitigation:** already covered in `proposal.md` Blast Radius; carried into the PR body and
  0.2.7 release notes per `tasks.md` hand-off. Not restated here.
- **[Risk] An inert `gpuRanker` key remains in the chainguard preset** (see nodeLabels decision
  above) → **Mitigation:** annotated in place so a reader is told it is unused under
  `mode: ingest` and why it cannot simply be deleted. `values.schema.json` is untouched, so no
  validation rule was weakened to accommodate a cosmetic cleanup.
- **[Risk] A future full-suite `helm unittest -u` regen (by a human, outside this change) could
  re-introduce the dropped-empty-label / reordering churn** on files this change didn't touch →
  **Mitigation:** none added by this change beyond documenting the hazard here; the existing
  `.build/bin/verify-helm-snapshots.py` CI check already catches it before merge.

## Migration Plan

Single repo (`groundx-on-prem`), single level, no coordinated rollout — see `proposal.md` for the
full blast radius and the destructive-upgrade disclosure. No schema or seed-data migration and no
chart-contract change: the `values.schema.json` relaxation considered during authoring (see the
`nodeLabels`/schema decision above) was implemented then reverted at the human gate in favor of
annotating `cluster.nodeLabels.gpuRanker` in place, so `values.schema.json` ships byte-unchanged on
both chart surfaces. Rollback is `helm rollback` to the prior chart
version (re-creates the deleted ranker objects from the previous release's manifest; no state was
preserved to restore, matching `proposal.md`).

## Open Questions

None outstanding — the fix shape, assertion mechanism, corrected snapshot-regen scope, guard
design, and the `nodeLabels`/schema resolution above were all resolved with direct empirical
evidence during this authoring pass. The `nodeLabels` schema relaxation was reviewed by a human at
the plan gate and rejected in favor of the annotate-in-place resolution (see the `nodeLabels`/schema
decision above); `values.schema.json` is byte-unchanged on both chart surfaces. Nothing remains
open.
