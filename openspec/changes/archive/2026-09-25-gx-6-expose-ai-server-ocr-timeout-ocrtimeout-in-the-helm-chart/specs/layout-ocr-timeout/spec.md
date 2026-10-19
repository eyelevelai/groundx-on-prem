## ADDED Requirements

### Requirement: `layout.ocr.timeout` is exposed as a bounded, backward-compatible Helm value

The chart SHALL expose a `layout.ocr.timeout` value (integer, minimum 1, maximum 250) that
renders unquoted as `ocrTimeout=<int>` in the shared `layout-config-py-map` Secret's `config.py`
(the layout Celery workers' rendered config), identically in `src/groundx` and its `helm/`
mirror. A value outside `[1, 250]` SHALL fail Helm's schema validation before any resource
renders. When the value is unset, the chart SHALL render `ocrTimeout=120` — the same default the
`ai-server` `ocr_tesseract.py` reader already falls back to (`int(env.get("ocrTimeout", 120))`),
so an unupgraded or override-free deployment observes no behavior change.

#### Scenario: unset renders the backward-compatible default (polarity: finalize success; backward-compatibility scenario)

- **GIVEN** `layout.ocr.timeout` is not set (every values file the chart ships or tests with
  today)
- **WHEN** `helm template` renders `templates/resources/layout-config-py.yaml` (`src/groundx` and,
  independently, the `helm/` mirror)
- **THEN** the rendered `config.py` contains `ocrTimeout=120`, matching the default the
  `ai-server` OCR reader already uses on unmerged and already-deployed installs
- **AND THEN** no other line in the rendered `config.py` changes from before this change (no
  existing `helm unittest` snapshot for an unset-timeout values file is altered by this change,
  aside from the new `ocrTimeout=120` line and its accompanying `config-hash` annotation) — the
  opposite outcome, a behavior change for deployments that never set this value, must not occur

#### Scenario: a valid override renders exactly, unquoted (polarity: finalize success)

- **GIVEN** `layout.ocr.timeout: 187` (a distinctive in-range value, not the default)
- **WHEN** `helm template` renders `templates/resources/layout-config-py.yaml` (both chart
  surfaces)
- **THEN** the rendered `config.py` contains `ocrTimeout=187` as a bare (unquoted) integer
  literal — the same rendering convention as the sibling `minBatchSize` field — so `ai-server`'s
  unguarded `int(env.get("ocrTimeout", 120))` receives an `int`, not a string
- **AND THEN** the rendered value is not `"187"` (quoted) and no other pod's rendered config is
  affected (the opposite outcome — a quoted or leaked value — must not occur)

#### Scenario: a value above the ceiling is rejected before any resource renders (polarity: reject before state)

- **GIVEN** `layout.ocr.timeout: 251` (one above the schema ceiling)
- **WHEN** `helm template` (or `helm install`/`upgrade`) evaluates the release against
  `values.schema.json`
- **THEN** schema validation fails and **no** Kubernetes resource is rendered or applied — in
  particular, no `layout-config-py-map` Secret is created or updated with a stale or partial
  `ocrTimeout` value
- **AND THEN** the failure names the offending path (`layout/ocr/timeout`) rather than failing on
  an unrelated field, so a human reviewing the error can locate the cause (the opposite outcome —
  silently coercing or truncating the value instead of rejecting it — must not occur)

#### Scenario: a value below the minimum is rejected before any resource renders (polarity: reject before state)

- **GIVEN** `layout.ocr.timeout: 0`
- **WHEN** `helm template` evaluates the release against `values.schema.json`
- **THEN** schema validation fails and no resource renders, for the same reason as the
  above-ceiling case — a zero or negative per-page OCR timeout is never a valid deployment

### Requirement: the ceiling keeps the worst-case OCR retry inside Celery's task time limit

`layout.ocr.timeout`'s schema maximum (250) SHALL keep the worst-case per-page Tesseract OCR
retry path (at most 2 attempts, full-resolution then one downscaled retry, per the `ai-server`
FRA-115 budget) below the layout Celery workers' `TaskTO=600` soft time limit, leaving headroom
for surrounding work (image load, downscale, upload) that the chart does not itself measure or
gate.

#### Scenario: the documented ceiling leaves margin under the Celery soft time limit (polarity: finalize success)

- **GIVEN** `layout.ocr.timeout` set to the schema maximum, 250
- **WHEN** the worst case is computed as at most 2 Tesseract attempts × 250s = 500s
- **THEN** 500s stays below the `TaskTO=600` Celery soft time limit the layout workers run under,
  leaving roughly 100s of margin for the surrounding non-OCR work in the same task
- **AND THEN** this is a documented arithmetic bound, not a per-request runtime check the chart
  enforces — the chart's only enforcement mechanism is the static schema ceiling on the
  configured value, not the actual elapsed OCR call time
