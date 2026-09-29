## ADDED Requirements

### Requirement: every `layout-process` pod gets a per-pod, disk-backed render temp volume, wired automatically

The chart SHALL mount a disk-backed (not `medium: Memory`) `emptyDir` volume into every
`layout-process` pod at a dedicated path (e.g. `/tmp/render`), created and torn down with the pod
by Kubernetes on `helm upgrade` — with no `PersistentVolumeClaim`, `StorageClass`, pod affinity,
or manual operator step, and no constraint on horizontal scaling (the volume is per-pod, never
shared or `ReadWriteOnce`-bound). Only the `layout-process` Deployment is affected; the other
layout Celery workers (`correct`, `map`, `ocr`, `save`) and the `api`/`inference` pods, which
render from their own `.settings` helpers, are untouched.

#### Scenario: the render temp volume, mount, and env are present at chart defaults (polarity: finalize success)

- **GIVEN** the chart's default values (no `layout.process.renderDiskBudgetMi` override)
- **WHEN** `helm template` renders the `layout-process` Deployment
- **THEN** the pod spec contains an `emptyDir` volume with no `medium: Memory` field, a
  `volumeMount` for it on the container at the dedicated render path, and container env vars
  `TMPDIR=<mount path>` and `LAYOUT_RENDER_DISK_BUDGET_MIB=2048`

#### Scenario: the render temp volume adds no PVC, StorageClass, or affinity (polarity: finalize success; catches the adversarial counterexample)

- **GIVEN** the rendered `layout-process` Deployment from the scenario above
- **WHEN** the full rendered manifest set for `layout-process` is inspected
- **THEN** it contains no `PersistentVolumeClaim`, no `volumeClaimTemplate`, no new
  `StorageClass` reference, and no new or changed `affinity`/`nodeSelector` rule beyond what
  `layout.process.affinity`/`nodeSelector` already render today — the render temp volume is the
  only new manifest content this requirement adds

#### Scenario: the volume stays per-pod under multiple replicas and HPA, so horizontal scaling is not blocked (polarity: finalize success; must not block)

- **GIVEN** `layout.process.replicas.desired: 3` and `layout.process.replicas.hpa: true`
- **WHEN** `helm template` renders the `layout-process` Deployment and (where the chart's HPA
  path is enabled) its `HorizontalPodAutoscaler`
- **THEN** every replica's pod template carries its own independent `emptyDir` (not a shared or
  `ReadWriteOnce` volume claimed once for the Deployment), the Deployment's `replicas` field and
  HPA min/max render exactly as they do without this change, and no replica-count-dependent
  volume, affinity, or `StatefulSet` conversion appears — scaling `layout-process` out is not
  newly constrained by this change

#### Scenario: an unpatched image on the patched chart leaves the mount and env unused, harmlessly (backward-compatibility scenario, cross-service touchpoint with `ai-server`; polarity: finalize success)

- **GIVEN** the patched chart is deployed with a `layout-process` image built before `ai-server`'s
  companion change (same ticket) lands
- **WHEN** the pod starts
- **THEN** the emptyDir is mounted and `TMPDIR`/`LAYOUT_RENDER_DISK_BUDGET_MIB` are set in the
  container environment, but the deployment is otherwise unaffected — nothing in this chart change
  requires the running image to read either value, so an old image continues rendering PDFs
  exactly as it does today, using whatever temp directory its own code already resolves

### Requirement: `layout.process.renderDiskBudgetMi` is the single source for the app's disk budget and the volume's ceiling

The chart SHALL expose one optional value, `layout.process.renderDiskBudgetMi` (integer,
`minimum: 1`, default `2048`) — the per-worker-process render-temp disk budget in MiB that
`ai-server` enforces as its primary out-of-memory guard. The chart SHALL always compute
`emptyDir.sizeLimit` and `resources.requests.ephemeral-storage` from the same formula, `workers ×
threads × renderDiskBudgetMi + 1024` MiB (`3072Mi` at the 0.2.7 defaults of 1 worker × 1 thread) —
the 1 GiB reserve keeps the app's own enforced budget below the volume's ceiling, so the app
refuses an oversized render chunk before Kubernetes would evict the pod on disk pressure. The
computed `ephemeral-storage` request SHALL replace any user-supplied one; every other key under
`layout.process.resources` SHALL be preserved unchanged, and `.Values` SHALL NOT be mutated.

#### Scenario: the default budget sizes the volume ceiling and the app's request identically (polarity: finalize success)

- **GIVEN** the chart's default values (`renderDiskBudgetMi` unset, 1 worker × 1 thread)
- **WHEN** `helm template` renders the `layout-process` Deployment
- **THEN** `emptyDir.sizeLimit` is `3072Mi`, `resources.requests["ephemeral-storage"]` is
  `3072Mi`, and the container env `LAYOUT_RENDER_DISK_BUDGET_MIB` is `2048` — one number
  (`2048`) is the sole input to all three rendered fields

#### Scenario: an override scales the volume ceiling, the request, and the env consistently (polarity: finalize success)

- **GIVEN** `layout.process.renderDiskBudgetMi: 4096` and `layout.process.workers: 2`
- **WHEN** `helm template` renders the `layout-process` Deployment
- **THEN** `emptyDir.sizeLimit` is `9216Mi` (`2 × 1 × 4096 + 1024`),
  `resources.requests["ephemeral-storage"]` is `9216Mi`, and `LAYOUT_RENDER_DISK_BUDGET_MIB` is
  `4096` — all three follow the override together, never independently

#### Scenario: a below-minimum budget is rejected before any resource renders (polarity: reject before state)

- **GIVEN** `layout.process.renderDiskBudgetMi: 0`
- **WHEN** `helm template` (or `helm install`/`upgrade`) evaluates the release against
  `values.schema.json`
- **THEN** schema validation fails and no Kubernetes resource renders or applies — in particular,
  no `layout-process` Deployment renders with a zero or negative `sizeLimit`/`ephemeral-storage`
  value

#### Scenario: a user-supplied ephemeral-storage request is replaced, but every other resources key survives untouched (polarity: finalize success; catches the adversarial counterexample)

- **GIVEN** `layout.process.resources` already sets `requests.cpu: 250m`,
  `requests.memory: 2Gi`, and `requests["ephemeral-storage"]: 500Mi` (a stale, too-small value an
  operator had set before this change existed)
- **WHEN** `helm template` renders the `layout-process` Deployment at the chart's default
  `renderDiskBudgetMi`
- **THEN** `requests["ephemeral-storage"]` renders as the chart-computed `3072Mi` (the
  user-supplied `500Mi` is replaced, never merged or summed with it), while `requests.cpu:
  250m` and `requests.memory: 2Gi` render unchanged — the same render, run twice, must not show
  the computed value leaking into a second, unrelated release's `resources` block (the values
  dict passed in is never mutated in place)

## Amendments

### 2026-09-29 — review round 1 fix (G1, G2, G3)

- **G1/G2 — two new requirements added below**, each with a `reject before state` scenario: the
  chart now `fail`s template rendering rather than silently rendering an invalid manifest when a
  user-set `ephemeral-storage` limit is below the computed request, or when `workers`/`threads` is
  below 1.
- **G3 — clarification on the "single source" requirement's mutation clause (text above is left
  as originally written; this note does not edit it).** The requirement's "...and `.Values` SHALL
  NOT be mutated" clause, and the last scenario's "the same render, run twice, must not show the
  computed value leaking into a second, unrelated release's `resources` block (the values dict
  passed in is never mutated in place)" clause, are **not** independently exercised by any test in
  this spec — confirmed empirically: `groundx.layout.process.settings` computes the same
  deterministic value from the same inputs on every call within one render (it is called twice per
  render, from `templates/app/celery.yaml` and `templates/resources/layout-supervisord-conf.yaml`,
  and always overwrites the `ephemeral-storage` key with the freshly computed value), so removing
  the `deepCopy` calls in a scratch copy of the chart still passes every existing test in this
  spec. The `deepCopy` merge itself is unchanged and correct; it remains documented as a code-level
  implementation decision in `design.md` (following the `layout-inference.tpl:239` precedent). A
  reader should treat those two clauses as an implementation guarantee recorded in `design.md`, not
  as a scenario this spec's tests assert.
- **Correction to the per-pod/HPA scenario above:** `src/groundx/tests/celery_test.yaml`'s matching
  test ("the emptyDir volume stays per-pod under multiple replicas and HPA, not shared or bound")
  now also renders `templates/resources/hpa.yaml` and asserts the `layout-process-hpa`
  `HorizontalPodAutoscaler`'s `minReplicas`/`maxReplicas`, closing the previously-untested HPA half
  of this scenario. Note: `layout.process.replicas.hpa` is not itself a schema-settable field
  (`values.schema.json`'s `layout.process.replicas` block only allows `desired`/`max`/`min`, unlike
  e.g. `ranker.inference.replicas`, which also allows `hpa`/`cooldown`/`target`/`threshold`/
  `throughput`) — a pre-existing gap outside this ticket's scope. The test instead enables HPA via
  the cluster-wide `cluster.hpa: true` toggle (the same mechanism `tests/ranker_test.yaml` already
  uses), which `layout.process`'s HPA path inherits when its own `replicas.hpa` is unset.

### Requirement: the chart rejects an under-sized `ephemeral-storage` limit rather than producing an invalid pod

The chart SHALL fail template rendering (`fail`) when
`layout.process.resources.limits["ephemeral-storage"]` is set below the computed
`ephemeral-storage` request, naming `layout.process.renderDiskBudgetMi` and the offending limit in
the error — never silently raising the operator's limit or silently producing a request above its
own limit.

#### Scenario: an under-sized ephemeral-storage limit is rejected before any resource renders (polarity: reject before state)

- **GIVEN** `layout.process.resources.limits["ephemeral-storage"]: 1Gi` at the chart's default
  budget (computed request `3072Mi`)
- **WHEN** `helm template` renders the release
- **THEN** rendering fails with an error naming `layout.process.renderDiskBudgetMi` and the
  configured limit, and no `layout-process` Deployment renders

#### Scenario: a limit at or above the computed request renders unchanged (polarity: finalize success; must not block)

- **GIVEN** `layout.process.resources.limits["ephemeral-storage"]: 4Gi` at the chart's default
  budget
- **WHEN** `helm template` renders the release
- **THEN** the `layout-process` Deployment renders normally with `limits["ephemeral-storage"]: 4Gi`
  and `requests["ephemeral-storage"]: 3072Mi`

### Requirement: the chart rejects `workers`/`threads` below 1 for `layout.process`

The chart SHALL fail template rendering (`fail`) when `layout.process.workers` or
`layout.process.threads` is below `1`, rather than rendering a negative or zero
`emptyDir.sizeLimit`/`ephemeral-storage` value. This is a template-level guard scoped to
`layout.process`'s render-disk formula; it does not add a schema `minimum` to the shared
`workers`/`threads` properties other services also declare.

#### Scenario: a negative workers or threads value is rejected before any resource renders (polarity: reject before state)

- **GIVEN** `layout.process.workers: -1` (or, separately, `layout.process.threads: -1`)
- **WHEN** `helm template` renders the release
- **THEN** rendering fails with an error naming the offending field and its value, and no
  `layout-process` Deployment renders with a negative-sized volume or request
