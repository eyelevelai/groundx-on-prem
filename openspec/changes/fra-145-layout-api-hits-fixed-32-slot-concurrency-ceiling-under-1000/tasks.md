## 1. Layout API probe timing — thin vertical slice

- [x] 1.1 Add tolerant probe-timing rendering to the shared `src/groundx/templates/app/api.yaml`
      liveness/readiness blocks (defaulting to `3`/`3`/`3` via `dig` so a service that has not yet
      supplied a `probe` dict keeps rendering unchanged), and wire `layout` end-to-end: the
      `api.probe.{liveness,readiness}` nested object in `src/groundx/values.schema.json`'s
      `layout.api` block (each nesting level `additionalProperties: false`, per `design.md`), the
      `groundx.layout.api.probe` helper in `src/groundx/templates/_helpers/app/layout-api.tpl`
      threading it into `groundx.layout.api.settings`, and the shipped defaults in
      `layout.api.probe` in `src/groundx/values.yaml`.
      check: cd src/groundx && helm unittest -f 'tests/api-probe-layout_test.yaml' .

## 2. Widen to the remaining four services

- [x] 2.1 Repeat 1.1's schema/helper/values wiring for `ranker`
      (`src/groundx/templates/_helpers/app/ranker-api.tpl`).
      check: cd src/groundx && helm unittest -f 'tests/api-probe-ranker_test.yaml' .
- [x] 2.2 Repeat 1.1's schema/helper/values wiring for `summary`
      (`src/groundx/templates/_helpers/app/summary-api.tpl`).
      check: cd src/groundx && helm unittest -f 'tests/api-probe-summary_test.yaml' .
- [x] 2.3 Repeat 1.1's schema/helper/values wiring for `extract`
      (`src/groundx/templates/_helpers/app/extract-api.tpl`).
      check: cd src/groundx && helm unittest -f 'tests/api-probe-extract_test.yaml' .
- [x] 2.4 Repeat 1.1's schema/helper/values wiring for `workspace`
      (`src/groundx/templates/_helpers/app/workspace-api.tpl`, reading through
      `groundx.workspace.api.values`).
      check: cd src/groundx && helm unittest -f 'tests/api-probe-workspace_test.yaml' .

## 3. Operator overrides

- [x] 3.1 Confirm an operator's `<service>.api.probe.{liveness,readiness}` override renders
      exactly as set, and does not leak into a sibling service's Deployment in the same render
      (no code change expected beyond 1.1–2.4's generic `dig`-based wiring; this task closes the
      loop with a regression test).
      check: cd src/groundx && helm unittest -f 'tests/api-probe-override_test.yaml' .

## 4. Values-schema validation

- [x] 4.1 Confirm the values schema rejects an undeclared key under `api.probe`/`api.probe.liveness`/
      `api.probe.readiness` and a non-integer `timeoutSeconds`/`failureThreshold`, for all five
      services (no code change expected beyond 1.1–2.4's `additionalProperties: false` nesting;
      this task closes the loop with the rejection tests).
      check: cd src/groundx && helm unittest -f 'tests/api-probe-schema_test.yaml' .

## 5. Mirror sync

- [x] 5.1 Manually sync the four touched files
      (`values.schema.json`, `values.yaml`, `templates/app/api.yaml`, and the five touched
      `templates/_helpers/app/*-api.tpl` files) from `src/groundx` into `helm/`, matching this
      repo's existing hand-sync convention (`AGENTS.md` "Agent boundaries").
      check: bash src/groundx/tests/files/verify-probe-mirror-drift.sh

## 6. Snapshot regeneration (separate commit hunk)

- [x] 6.1 Regenerate the affected `helm-unittest` snapshots
      (`src/groundx/tests/__snapshot__/{api,ranker,workspace}_test.yaml.snap`) via
      `helm unittest -u src/groundx`, committed separately from the template/schema/values edits
      in tasks 1–5 so the behavioral diff stays readable.
      check: n/a — golden-file regeneration; verified by the full validator in task 7

## 7. Final gate

- [x] 7.1 Run the repo's own CI-parity validator, covering both chart surfaces (lint, the full
      `helm unittest` suite including every test file above, and this repo's other chart
      contract checks).
      check: bash .build/bin/validate-helm.sh

Cross-service coordination note: this change is one of two same-level, either-may-ship-first
changes for FRA-145 (the other is the paired `ai-server` fix for the actual incident root cause).
See the workspace `openspec/changes/<FEATURE_BRANCH>/tasks.md` for cross-service coordination and
any deferred follow-up items; none of that coordination is a checkbox in this file.
