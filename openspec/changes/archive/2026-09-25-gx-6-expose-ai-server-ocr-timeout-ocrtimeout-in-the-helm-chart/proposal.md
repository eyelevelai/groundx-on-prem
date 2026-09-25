## Why

FRA-115 added a configurable per-page Tesseract OCR timeout in `ai-server`
(`document/ocr_tesseract.py:84`, read as `int(env.get("ocrTimeout", 120))`), but
the chart never renders an `ocrTimeout` key into the layout config Secret, so
every deployment is stuck at the hardcoded 120s default and operators cannot
tune it. FRA-115 merged to `ai-server` master 2026-08-18 (0.2.7 tag), so the
dependency this ticket blocks on is satisfied.

## What Changes

- Add an optional values key `layout.ocr.timeout` (integer, `minimum: 1`,
  `maximum: 250`) to `values.schema.json` under `layout.ocr`
  (`additionalProperties: false`, so this is a deployment-contract addition,
  not just a template edit).
- Add one Helm helper `groundx.layout.ocr.timeout` in
  `templates/_helpers/app/layout-ocr.tpl`, mirroring the existing
  `groundx.layout.ocr.type` pattern (`dig "timeout" 120 $in`).
- Render it as an unquoted `ocrTimeout=<int>` line in
  `templates/resources/layout-config-py.yaml` (the shared
  `<svc>-config-py-map` Secret every layout worker consumes), alphabetically
  between `ocrProject` and `ocrType`.
- Add a one-line comment in `values.yaml` next to `layout.ocr` documenting the
  120 default and the 250 ceiling.
- Apply the identical four edits to the `helm/` manual mirror.
- Extend the existing `src/groundx/tests/resources_test.yaml` with one
  override case (`timeout: 187` → `ocrTimeout=187`) and one schema-rejection
  case (`timeout: 251` fails validation). No new test files, no new CI.
- Regenerate the affected `helm unittest` snapshots (`resources`, `api`,
  `celery`, `inference`) with `helm unittest -u` under the pinned helm
  v3.19.0, in their own commit, confirming the diff is only the new config
  line plus `config-hash` annotation churn.

Unset behavior is unchanged: no override renders `ocrTimeout=120`, identical
to today's implicit default — this is a backward-compatible, additive change.

## Capabilities

### New Capabilities
- `layout-ocr-timeout`: a new, optional `layout.ocr.timeout` values key that
  renders as `ocrTimeout=<int>` in the shared layout `config.py` Secret,
  bounded `1..250` by the values schema, defaulting to 120 when unset.

### Modified Capabilities
(none — this adds a new schema key and a new rendered config line; it does
not change the requirements of any existing spec, including
`layout-ocr-credentials-render`, which governs OCR credential wiring, not
the timeout value.)

## Impact

- **Affected code**: `src/groundx/values.schema.json`, `src/groundx/values.yaml`,
  `src/groundx/templates/_helpers/app/layout-ocr.tpl`,
  `src/groundx/templates/resources/layout-config-py.yaml`,
  `src/groundx/tests/resources_test.yaml`,
  `src/groundx/tests/__snapshot__/*.snap` (regenerated), and the identical
  four files under `helm/`.
- **Affected environments**: every install of this chart, including Fraud-X
  once it re-vendors 0.2.7 at a newer pinned commit. Merging to `0.2.7` does
  not by itself reach Fraud-X prod, which vendors the chart at a fixed commit.
- **Blast radius / rollout**: `layout-config-py-map` is a shared Secret
  consumed by every layout Celery worker (`correct`, `map`, `ocr`, `process`,
  `save`) and the layout API/inference pods. Because the Secret's content
  changes (a new key is always present, even at the default), its
  `config-hash` annotation changes, so **all layout pods across every
  deployment restart once on upgrade** — even deployments that never set
  `layout.ocr.timeout`. This is a one-time rolling restart, not downtime
  (existing readiness probes gate the rollout); it is called out explicitly
  in the PR/release notes.
  Rendered override only changes OCR *behavior* when `layout.ocr.type` is
  the default `tesseract` — Google Cloud Vision OCR ignores this value.
  The value is inert until an `ai-server` image built at or after the
  FRA-115 merge is deployed; `helm/Chart.yaml` on `0.2.7` still reads
  `appVersion 0.2.6` (unchanged by this proposal — noted, not fixed here).
- **Rollback**: reverting this change (or unsetting the value) restores the
  implicit 120s default with no data-path or schema-breaking impact — the
  chart change is purely additive and behind a values default; rollback is a
  standard `helm rollback` / revert of this PR.
- **Data / stateful-resource impact**: none. No schema/database migration,
  no persisted-state change — this only affects an env value baked into a
  rendered Kubernetes Secret at deploy time.
- **Dependencies**: none upstream; downstream consumer is `ai-server`'s
  existing reader (`document/ocr_tesseract.py:84`, already on master — no
  `ai-server` change needed) and `groundx-studio-harness` (documentation
  only, Level 2, out of scope for this proposal).
- **Open design questions**: none — the plan gate already resolved the key
  name (`layout.ocr.timeout`, precedent `layout.api.timeout`), the schema
  ceiling (250, from the FRA-115 review's revised 1-call/attempt budget),
  and the snapshot-regeneration procedure (regenerate with `helm unittest -u`
  under the pinned helm v3.19.0, confirm the snapshot diff is only the new
  `ocrTimeout` line plus `config-hash` lines, and stop and escalate if any
  label drops or reorders; snapshots are never hand-edited); see this
  change's `design.md` for the recorded decisions and rationale.
