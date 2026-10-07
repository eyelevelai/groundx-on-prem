## Why

`src/groundx/templates/app/celery.yaml`'s `$mountOCR` predicate (line 23) is not scoped to layout
workers: `$mountOCR := and (eq $ocrCreate "true") (or (eq $hasOCR "true") $sharedGoogle)` fires for
**every** Celery worker once layout has packaged Google OCR credentials configured, because
`$hasOCR`/`$ocrCreate` are computed once from layout settings and reused unscoped inside the
per-worker `range`. With `layout.ocr.credentials` set and extraction or workspace background
workers enabled, `helm template`/`helm upgrade` fails outright (`no template
"groundx/templates/resources/extract-ocr-credentials.yaml"`) or, once the annotation alone is
patched, renders a `credentials-volume` pointing at a nonexistent `extract-ocr-credentials-map` /
`workspace-ocr-credentials-map` Secret — a deployment that installs but whose extract/workspace
pods cannot start. `$sharedGoogle` (line 22) is already correctly layout-scoped and must not
regress. Fix now: this blocks GX-50's OCR-image-dependency validation, which needs a real
packaged-credential deployment with extraction and workspace workers enabled to test against.

## What Changes

- Scope `$mountOCR` in `src/groundx/templates/app/celery.yaml` to layout Celery workers only
  (`and (eq $mapPrefix "layout") (eq $ocrCreate "true") (eq $hasOCR "true")`, or equivalent),
  preserving `$sharedGoogle`'s existing layout scoping unchanged. This is the single guard that
  drives all three sites: the `ocr-credentials-hash` annotation (L73/74), the
  `/app/credentials.json` volume mount (L181), and the `credentials-volume` Secret volume
  (L199, with its `else` branch `secretName: {{ $svc }}-ocr-credentials-map` at L208).
- Mirror the identical corrected predicate into `helm/templates/app/celery.yaml` (byte-identical
  to `src/groundx/templates/app/celery.yaml` at 0.2.7) so the published chart carries the same fix.
- Extend the existing `src/groundx/tests/celery_test.yaml` helm-unittest suite with a mixed-worker
  regression case (packaged `layout.ocr.credentials` + extraction + workspace workers all
  enabled) that fails on the unchanged chart and asserts: no `extract-ocr-credentials-map` /
  `workspace-ocr-credentials-map` / other non-layout OCR-credentials Secret reference renders,
  and the extraction and workspace Deployments are actually present in the rendered output (not
  merely absent-by-being-disabled).
- Extend the existing dual-surface render check in `.build/bin/validate-helm.sh` (the
  `src/groundx` + `helm` loop) so the packaged-credentials-with-mixed-workers path is exercised
  on both chart surfaces, reusing the existing `values.ocr-google.yaml` fixture and the
  extract/workspace `--set` shape already used by the shared-Google isolation checks.
- No new test file and no new CI/guard — everything above extends suites and a runner this repo
  already ships.

Not changed: `values.schema.json`, `values.yaml` defaults, the `google.credentials` /
`google.existingSecret` shared-credential path, legacy `layout.ocr.credentials` precedence over
shared credentials, disabled-OCR behavior, or Tesseract-without-credentials behavior — all five
are existing render paths this fix must leave byte-identical.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `layout-ocr-credentials-render`: today's requirement only guarantees the `$hasOCR`-guarded
  annotation/mount/volume sites render as **valid YAML** on both branches of the guard. This
  change adds the missing requirement that those same three sites evaluate `$mountOCR` **scoped
  to layout workers only** — a non-layout Celery worker (extraction, workspace) must never
  evaluate the guard true, must never emit the annotation/mount/volume, and must never reference
  a non-layout OCR-credentials Secret that does not exist.

## Impact

- **Code:** `src/groundx/templates/app/celery.yaml`, `helm/templates/app/celery.yaml` (template
  logic only — no new resource kind, no new template file); `src/groundx/tests/celery_test.yaml`
  (extended); `.build/bin/validate-helm.sh` (extended render-check loop).
- **Affected environments:** every environment — self-hosted/air-gapped customer installs and any
  internal validation cluster — that upgrades to a chart carrying this fix while running
  `layout.ocr.type=google` with a packaged `layout.ocr.credentials` file **and** extraction and/or
  workspace background workers enabled. Today that exact combination cannot successfully deploy at
  all (`helm template`/`helm upgrade` fails or the resulting pods cannot start), so no live
  environment currently depends on the broken behavior being fixed. Deployments using
  `google.credentials` / `google.existingSecret` (the shared-credential path), Tesseract, or OCR
  disabled are unaffected — this change does not alter those render paths.
- **Stateful/data impact:** none. This is Celery Deployment template logic only; no
  Secret/ConfigMap kind changes, no schema changes, no database or storage migration.
- **Rollback/rollforward:** standard chart-version rollback (`helm rollback`) — the change alters
  only which Deployments in the existing `range` emit the OCR annotation/mount/volume; it does not
  rename or restructure any resource, so a rollback returns to the prior (broken-for-this-one-
  combination) template with no state to reconcile. Rollforward is a normal chart upgrade; no
  manual migration or ops step is required.
