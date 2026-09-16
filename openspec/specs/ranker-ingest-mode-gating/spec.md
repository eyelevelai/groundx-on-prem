# ranker-ingest-mode-gating Specification

## Purpose
Make ingest-only mode authoritative over the ranker microservices, so `mode: ingest` suppresses
the retrieval-side `ranker.api` and `ranker.inference` workloads and everything they own even
when a values file sets `ranker.*.enabled: true`, matching the behavior `groundx.search.create`
already has and the harness documents. A CI gate holds the property on both chart surfaces,
including the `helm/` mirror that `helm unittest` never reaches.
## Requirements
### Requirement: The ranker API workload does not render under ingest-only mode
The system SHALL NOT render the `ranker-api` Deployment or Service from
`templates/app/api.yaml` when `mode: ingest`, on both chart surfaces
(`src/groundx` and `helm`), regardless of an explicit `ranker.api.enabled: true` — while the
sibling `extract-api`, `layout-api`, and `summary-api` workloads that `mode: ingest` still needs
continue to render unchanged. **Polarity: reject before state** — the ranker-api Deployment,
Service, the `ranker-config-py-map` Secret, and the `ranker-gunicorn-conf-py-map` ConfigMap
(which key off the same `groundx.ranker.api.create` helper) must not be created at all under this
mode; this is not a "created then hidden" behavior.

#### Scenario: Ranker API absent while sibling API services still render
- **WHEN** the chart renders `templates/app/api.yaml` with `mode: ingest` and the chart's own
  `ranker.api.enabled: true` default left in effect (no `ranker.*` override)
- **THEN** no document with `kind: Deployment` and `metadata.name: ranker-api` renders, and
  documents with `metadata.name: extract-api`, `layout-api`, and `summary-api` still render

#### Scenario: An explicit ranker.api.enabled: true is overridden by ingest-only mode
- **WHEN** the chart renders `templates/app/api.yaml` with `mode: ingest` and
  `ranker.api.enabled` explicitly set to `true`
- **THEN** no document with `kind: Deployment` and `metadata.name: ranker-api` renders — the mode
  wins unconditionally over the explicit `enabled: true`, and no `ranker-api` state is created

### Requirement: The ranker inference workload does not render under ingest-only mode
The system SHALL NOT render the `ranker-inference` Deployment or the `ranker-model`
PersistentVolumeClaim from `templates/app/inference.yaml` when `mode: ingest`, on both chart
surfaces, regardless of an explicit `ranker.inference.enabled: true` — while the sibling
`layout-inference` and `summary-inference` workloads continue to render unchanged, and no
rendered document references the `eyelevel-gpu-ranker` node label (affinity or toleration). There
is no `ranker-inference` `Service` — `templates/app/inference.yaml` never calls
`groundx.renderInterface` (only `ranker-api` does, via `templates/app/api.yaml`). **Polarity:
reject before state.**

#### Scenario: Ranker inference absent while sibling inference services still render
- **WHEN** the chart renders `templates/app/inference.yaml` with `mode: ingest` and the chart's
  own `ranker.inference.enabled: true` default left in effect
- **THEN** no document with `kind: Deployment` and `metadata.name: ranker-inference` renders, and
  documents with `metadata.name: layout-inference` and `summary-inference` still render, and no
  rendered document contains the string `eyelevel-gpu-ranker`

#### Scenario: An explicit ranker.inference.enabled: true is overridden by ingest-only mode
- **WHEN** the chart renders `templates/app/inference.yaml` with `mode: ingest` and
  `ranker.inference.enabled` explicitly set to `true`
- **THEN** no document with `kind: Deployment` and `metadata.name: ranker-inference` renders — no
  ranker-inference state is created, even though the operator explicitly asked to enable it

### Requirement: No ranker HorizontalPodAutoscaler renders under ingest-only mode
The system SHALL NOT render a `ranker-api-hpa` or `ranker-inference-hpa`
`HorizontalPodAutoscaler` from `resources/hpa.yaml` when `mode: ingest`, even when
`cluster.hpa: true` (the setting that would otherwise default every service's `replicas.hpa` flag
to enabled). **Polarity: reject before state** — the HPA's own `.hpa` helper derives its
`enabled` flag from `groundx.ranker.*.create`, so this is a downstream consequence of the create
helpers, not a separate gate, and disabling it must require no additional template code.

#### Scenario: No ranker HPA renders even with cluster-wide HPA enabled
- **WHEN** the chart renders `resources/hpa.yaml` with `mode: ingest` and `cluster.hpa: true`
- **THEN** no document with `kind: HorizontalPodAutoscaler` and `metadata.name: ranker-api-hpa`
  or `metadata.name: ranker-inference-hpa` renders

### Requirement: Non-ingest chart renders are unaffected by the mode-first-ordering fix
The system SHALL render byte-identical output for `mode: all` (the default) before and after the
`groundx.ranker.{api,inference}.create` mode-first-ordering fix, on both chart surfaces.
**Polarity: skip unrelated repair path** — the ordering fix must not widen into rendering behavior
outside the `mode: ingest` case; a regenerated snapshot diff (from that fix) that touches any label
outside the `extract:`, `extract.ingest:`, or `extract.oai:` prefixes (the only fixture families
that set `mode: ingest`) is itself a defect in the fix, not an acceptable side effect.

**Exception, independent of `mode`:** `groundx.ranker.inference.busyWindowSeconds` gating on
`.create` (matching its `.threshold`/`.throughput` siblings — the review-round fix for the
asymmetry where it alone ignored `.create`) also corrects `ranker-config-py.yaml`'s
`metricsBusyWindowSeconds` line for any render where `ranker.inference.create` is `false`
regardless of `mode` — including a `mode: all` render where `ranker.inference` is individually
disabled (`ranker_test.yaml`'s `cache override: ranker api` case). That is a distinct, correctness
fix to a helper that was always wrong under this condition, not a widening of the mode-first
ordering fix; its own snapshot diff is scoped to that one label.

#### Scenario: mode: all rendering is unchanged
- **WHEN** the chart renders any template with `mode: all` (or `mode` left unset, the default)
- **THEN** the rendered output is identical to the pre-fix output for the mode-first-ordering fix,
  and the ranker-api and ranker-inference workloads still render as before — except for the
  `busyWindowSeconds` `.create`-gating correction named above, which is independent of `mode`

#### Scenario: The regenerated snapshot diff touches only ingest-mode-fixture blocks (mode-first-ordering fix)
- **WHEN** `src/groundx/tests/__snapshot__/{api,inference,resources,golang,metrics}_test.yaml.snap`
  are regenerated via `helm unittest -u` scoped to those five test files for the mode-first-ordering
  fix
- **THEN** every changed snapshot label is prefixed `extract:`, `extract.ingest:`, or
  `extract.oai:` — no `disabled:`, `cloud:`, `metadata:`, cache-override, or other non-ingest
  label changes, other than the separate `busyWindowSeconds` `.create`-gating fix's own
  `ranker_test.yaml` snapshot label named above

### Requirement: A CI gate rejects ranker rendering under ingest mode on both chart surfaces
The system SHALL fail its chart gate when, under `mode: ingest`, any of the seven ranker objects
renders on either chart surface — the `ranker-api` / `ranker-inference` Deployments, the
`ranker-api` Service, the `ranker-model` PersistentVolumeClaim, the `ranker-config-py-map` Secret,
or the `ranker-gunicorn-conf-py-map` / `ranker-inference-supervisord-conf-map` ConfigMaps — or when
an `eyelevel-gpu-ranker` node-label reference appears. It SHALL NOT fail when the sibling non-ranker
workloads that `mode: ingest` still needs render normally, so an over-blocking change is caught as
well as an under-blocking one. An explicit `ranker.*.enabled: true` SHALL NOT override the mode.

`src/groundx` is covered by `tests/ranker_test.yaml`; the published `helm/` mirror is covered by
`helm/tests/ranker_ingest_test.yaml`. Both run under `helm unittest`, which the gate already
invokes, so the mirror needs no separate mechanism. `helm/.helmignore` excludes `tests`, so the
mirror's suite does not ship in the packaged chart — verified by packaging and listing the tarball.

#### Scenario: catches — ranker renders under ingest mode on either chart surface
- **GIVEN** a chart surface whose ranker create helpers still test the explicit `enabled` key before ingest-only mode
- **WHEN** `helm unittest` runs that surface's ranker ingest suite
- **THEN** the suite fails, naming the ranker documents that rendered

#### Scenario: must not block — sibling services still render under ingest mode
- **GIVEN** a chart surface with the mode-first ordering in place
- **WHEN** `helm unittest` runs that surface's ranker ingest suite
- **THEN** the suite passes, and the sibling API and inference workloads that `mode: ingest` keeps are asserted present rather than treated as violations

#### Scenario: the mirror's suite does not ship in the packaged chart
- **GIVEN** `helm/tests/ranker_ingest_test.yaml` exists
- **WHEN** `helm package helm` runs
- **THEN** the resulting tarball contains no entries under `tests/`, because `helm/.helmignore` excludes them
