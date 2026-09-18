## Context

Builds on `proposal.md`'s diagnosis: `$mountOCR` (`src/groundx/templates/app/celery.yaml:23`) is
computed once per chart from layout's own settings and reused, unscoped, inside the per-worker
`range` — so packaged `layout.ocr.credentials` leaks OCR-credential wiring onto every other
Celery worker once extraction or workspace background workers are also enabled.

## Goals / Non-Goals

**Goals:**
- Scope `$mountOCR` so only the layout Celery worker (`$mapPrefix == "layout"`) evaluates it
  true, for every site it drives: the `ocr-credentials-hash` annotation (L73/74), the
  `/app/credentials.json` volume mount (L181), and the `credentials-volume` volume (L199, with
  its `else` branch `secretName: {{ $svc }}-ocr-credentials-map` at L208).
- Preserve `$sharedGoogle`'s existing layout-only scoping (L22) and the disjunct it contributes
  to `$mountOCR` — the shared-Google credential path must keep mounting on the layout worker
  when no packaged file is configured.
- Mirror the identical corrected predicate into `helm/templates/app/celery.yaml` (confirmed
  byte-identical to the source file today).
- Extend the existing `celery_test.yaml` helm-unittest suite and the existing dual-surface
  render-check loop in `.build/bin/validate-helm.sh` — no new test file, no new CI/guard.

**Non-Goals:**
- Redesigning OCR credential sourcing, defaults, or per-service Secret naming.
- Any change to `values.schema.json` or a `values.yaml` default.
- GX-50 (OCR image dependencies in `ai-server`) — sequenced after this fix and tested
  independently with shared credentials.

## Decisions

**Invariant** (this is a same-shaped-edit sweep across the three sites listed above): a Celery
worker's Deployment may carry the OCR-credentials annotation, `/app/credentials.json` mount, or
`credentials-volume` volume only when a Secret that satisfies that exact reference — the layout
worker's own `layout-ocr-credentials.yaml` Secret, or the already layout-scoped shared-Google
Secret — actually exists for that worker. It must never carry that wiring for a worker no such
Secret is created for.

1. **Predicate fix.** Add `(eq $mapPrefix "layout")` as a leading conjunct of `$mountOCR`,
   keeping the existing `(or (eq $hasOCR "true") $sharedGoogle)` disjunct:
   ```
   {{- $mountOCR := and (eq $mapPrefix "layout") (eq $ocrCreate "true") (or (eq $hasOCR "true") $sharedGoogle) -}}
   ```
   `$hasOCR`/`$ocrCreate` are computed once from layout's own settings, outside the per-worker
   `range` (celery.yaml:2-3), so they carry no worker identity — that is the whole defect.
   `$sharedGoogle` (celery.yaml:22) is already `and (eq $mapPrefix "layout") ...`, so once the
   new leading conjunct is added, the `$sharedGoogle` disjunct only ever fires when `$mapPrefix`
   is already `"layout"`. Keeping the disjunct (rather than dropping it, as the proposal's
   illustrative predicate `and (eq $mapPrefix "layout") (eq $ocrCreate "true") (eq $hasOCR
   "true")` would) matters: dropping it would regress the existing "OCR mounts the external
   shared Secret and selected key" test (`celery_test.yaml:14-35`), where `$hasOCR` is false
   (no packaged file) and only `$sharedGoogle` is true. This is a code-grounding correction to
   the proposal's "or equivalent" predicate, made after reading `google.tpl` and
   `layout-ocr.tpl` — `$sharedGoogle` requires `layout.ocr.credentials == ""`, so it and
   `$hasOCR` are mutually exclusive, and the disjunct is what lets the layout worker mount
   correctly under either sub-path.
2. **Mirror.** Apply the identical one-line edit to `helm/templates/app/celery.yaml`. The two
   files are confirmed byte-identical today (`diff` returns nothing), so the same edit applies
   verbatim; no other drift exists in this file to reconcile.
3. **Cross-service contract:** not applicable. This repo is `INDEPENDENT` for this change — a
   single-repo template fix with no producer/consumer contract to version, and (per proposal.md's
   Impact section) no live environment currently depends on the broken combination this fixes.
4. **Test placement.** Extend `src/groundx/tests/celery_test.yaml` with three new `it` blocks
   under the same mixed configuration (packaged `layout.ocr.credentials` + extraction workers +
   workspace worker all enabled): a must-not-block positive case on `layout-ocr`, and two
   catches/negative cases on `extract-download` and `workspace-workspace`, each also asserting
   the Deployment itself renders (so the check cannot pass vacuously by the worker being
   disabled). Extend the existing Google-OCR `for chart in src/groundx helm` loop in
   `.build/bin/validate-helm.sh` with the same mixed-worker configuration on both chart surfaces,
   reusing the existing `values.ocr-google.yaml` fixture and the extract/workspace `--set` shape
   already proven schema-legal by the shared-Google isolation block (`extract.enabled=true`,
   `extract.agent.enabled=true`, `extract.api.enabled=true`, `extract.download.enabled=true`,
   `extract.save.enabled=true`, `workspace.enabled=true`, `workspace.token=test-runner-token`),
   asserting absence of the `extract-ocr-credentials-map` / `workspace-ocr-credentials-map`
   tokens and presence of the `extract-download`, `extract-save`, and `workspace-workspace`
   Deployments. Both additions are authored now, in this change (RED on the unfixed predicate —
   `helm template` currently errors outright for this combination per proposal.md); no new test
   file and no new CI/guard.

## Risks / Trade-offs

- An over-broad fix that hardcodes a specific worker name (e.g. `$svc == "layout-ocr"`) instead
  of `$mapPrefix == "layout"` would also pass the narrow pre-existing "google OCR enabled" test
  (which only ever renders the layout-ocr worker), without being scoped the way every other
  layout-scoped guard in this file already is (`$sharedGoogle` uses `$mapPrefix`). Scoping on
  `$mapPrefix` keeps one scoping mechanism instead of introducing a second, competing one.
- This fix does not add a general drift check between `src/groundx` and `helm/` (a known,
  separately tracked repo gap per `AGENTS.md`); it proves only that this one file's mirrored
  predicate is correct, via the render-check loop running against both surfaces byte-identically.
- No ADR: this is a scoping-predicate correction to an existing guard, with the byte-identical
  mirror rule for this file already established; it introduces no new architecturally
  significant decision.

Rollout, blast radius, and rollback/rollforward are already documented in `proposal.md` (standard
chart-version rollback; no stateful or manual-ops step) and are unchanged by these decisions.
