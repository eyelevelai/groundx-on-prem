## ADDED Requirements

### Requirement: The ranker API workload does not render under ingest-only mode
The system SHALL NOT render the `ranker-api` Deployment or Service from
`templates/app/api.yaml` when `mode: ingest`, on both chart surfaces
(`src/groundx` and `helm`), regardless of an explicit `ranker.api.enabled: true` — while the
sibling `extract-api`, `layout-api`, and `summary-api` workloads that `mode: ingest` still needs
continue to render unchanged. **Polarity: reject before state** — the ranker-api Deployment,
Service, and ConfigMaps (which key off the same `groundx.ranker.api.create` helper) must not be
created at all under this mode; this is not a "created then hidden" behavior.

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
The system SHALL NOT render the `ranker-inference` Deployment, Service, or `ranker-model`
PersistentVolumeClaim from `templates/app/inference.yaml` when `mode: ingest`, on both chart
surfaces, regardless of an explicit `ranker.inference.enabled: true` — while the sibling
`layout-inference` and `summary-inference` workloads continue to render unchanged, and no
rendered document references the `eyelevel-gpu-ranker` node label (affinity or toleration).
**Polarity: reject before state.**

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

### Requirement: Non-ingest chart renders are unaffected by the ingest-only fix
The system SHALL render byte-identical output for `mode: all` (the default) before and after this
change, on both chart surfaces. **Polarity: skip unrelated repair path** — the fix must not widen
into rendering behavior outside the `mode: ingest` case; a regenerated snapshot diff that touches
any label outside the `extract:`, `extract.ingest:`, or `extract.oai:` prefixes (the only fixture
families that set `mode: ingest`) is itself a defect in the fix, not an acceptable side effect.

#### Scenario: mode: all rendering is unchanged
- **WHEN** the chart renders any template with `mode: all` (or `mode` left unset, the default)
- **THEN** the rendered output is identical to the pre-fix output, and the ranker-api and
  ranker-inference workloads still render as before

#### Scenario: The regenerated snapshot diff touches only ingest-mode-fixture blocks
- **WHEN** `src/groundx/tests/__snapshot__/{api,inference,resources,golang,metrics}_test.yaml.snap`
  are regenerated via `helm unittest -u` scoped to those five test files
- **THEN** every changed snapshot label is prefixed `extract:`, `extract.ingest:`, or
  `extract.oai:` — no `disabled:`, `cloud:`, `metadata:`, cache-override, or other non-ingest
  label changes

### Requirement: A CI gate rejects ranker rendering under ingest mode on both chart surfaces
The system SHALL provide a `.build/bin/validate-helm.sh` check that fails when `ranker-api` or
`ranker-inference` renders (as a Deployment or Service document, or via an
`eyelevel-gpu-ranker` node-label reference) under `mode: ingest`, on **both** `src/groundx` and
`helm`, and that does not fail when the sibling non-ranker workloads that `mode: ingest` still
needs render normally. This requirement exists because `helm/` has no `tests/` tree
(`.helmignore` excludes it from the package) and CI runs `helm unittest` against `src/groundx`
alone — this gate is the only mechanism that ever exercises the `helm/` mirror's ingest-mode
behavior. **Gate-class change — invariant:** under `mode: ingest`, no ranker Deployment/Service
document and no `eyelevel-gpu-ranker` reference may render on either chart surface, regardless of
an explicit `enabled: true`, while every other workload that mode leaves enabled still renders.

#### Scenario: catches — ranker renders under ingest mode on either chart surface
- **WHEN** `helm template <chart> --set mode=ingest` is run against a chart surface where the
  `ranker.api.create` or `ranker.inference.create` helper still returns `true` under
  `mode: ingest` (the pre-fix regression, or a chart surface whose mirror was left unfixed)
- **THEN** the gate exits non-zero, naming the chart surface and the forbidden document(s) found

#### Scenario: must not block — sibling services still render under ingest mode
- **WHEN** `helm template <chart> --set mode=ingest` is run against a chart surface where the
  ranker create helpers correctly return `false`, and a sibling service the chart normally
  renders under `mode: ingest` (e.g. `layout-api`) is present
- **THEN** the gate exits zero — it does not report the sibling service as a violation, and a
  broken implementation that also stops the sibling from rendering is reported as a distinct
  "must still render" failure rather than passing silently
