Cross-cutting note: every `helm unittest`/`helm template` check below MUST use the pinned
`v3.19.0` binary via `${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0}` — fail
loudly if the variable is unset rather than silently falling back to the ambient `helm`. This
authoring pass confirmed the ambient local `helm v4.2.2` silently rewrites
`tests/__snapshot__/resources_test.yaml.snap` on a **plain** `helm unittest` run (no `-u`),
dropping/reordering unrelated snapshot labels (see `design.md` Risks). If any check below leaves
`resources_test.yaml.snap` modified in a way not asserted by its own task, run `git checkout --
src/groundx/tests/__snapshot__/resources_test.yaml.snap` before continuing.

## 1. Render `layout.ocr.timeout` end-to-end in `src/groundx` (schema → render → tested — the thin vertical slice)

- [x] 1.1 Add `layout.ocr.timeout` to `src/groundx/values.schema.json`'s `layout.ocr` block:
      `"timeout": { "type": "integer", "minimum": 1, "maximum": 250 }`, inserted between the
      existing `"threads"` (line 1016) and `"tolerations"` (line 1017) properties, matching the
      alphabetical sibling ordering already used in that block.
      check: ${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0} template src/groundx --set layout.ocr.timeout=251 2>&1 | grep -c "layout/ocr/timeout.*maximum: got 251, want 250"
- [x] 1.2 Add the `groundx.layout.ocr.timeout` helper to
      `src/groundx/templates/_helpers/app/layout-ocr.tpl` — `dig "timeout" 120 $in`, the exact
      shape of the sibling `groundx.layout.api.timeout` helper
      (`templates/_helpers/app/layout-api.tpl:199-202`) — positioned between the existing
      `groundx.layout.ocr.threads` (line 158) and `groundx.layout.ocr.type` (line 164) helper
      definitions. Render it unquoted as
      `ocrTimeout={{ include "groundx.layout.ocr.timeout" . }},` in
      `src/groundx/templates/resources/layout-config-py.yaml`, on its own line between the
      existing `ocrProject=...,` and `ocrType=...,` lines (alphabetical, matching the file's
      existing key ordering).
      check: ${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0} template src/groundx --set layout.ocr.timeout=187 --show-only templates/resources/layout-config-py.yaml 2>&1 | grep -c 'ocrTimeout=187,'
- [x] 1.3 Add a one-line comment directly above `ocr:` in `src/groundx/values.yaml` (around line
      244) documenting the 250 ceiling and that the value only affects the Tesseract OCR path
      (Google OCR ignores it) — no ticket ID, no narration, one line.
      check: n/a — comment-only documentation change, no rendered behavior to assert
- [x] 1.4 Extend `src/groundx/tests/resources_test.yaml` with the override case
      (`layout.ocr.timeout: 187` renders `ocrTimeout=187,`) and the rejection case
      (`layout.ocr.timeout: 251` fails schema validation) — **already committed in this authoring
      pass** as the two new `it:` cases immediately before `"existing: resources"`. This task
      exists to gate that they pass once 1.1–1.2 are implemented; do not add further test files.
      The temporary Google-OCR credential fixture this check generates is required only because
      `layout-ocr-credentials.yaml` reads `.Files.Get` on a path that must exist for the suite to
      render at all — mirror `.build/bin/validate-helm.sh`'s exact fixture content (not a bare
      stub), since the stub content mismatches the `"shared Google credentials: resources"`
      snapshot's expected values and makes the suite exit non-zero for a reason unrelated to this
      task; ensure the fixture is always removed after the run, success or failure.
      check: HB="${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0}"; f=src/groundx/files/ocr/gcv-test.json; created=0; if [ ! -e "$f" ]; then mkdir -p "$(dirname "$f")"; printf '%s\n' '{' '  "type": "service_account",' '  "project_id": "groundx-helm-test",' '  "private_key_id": "test",' '  "client_email": "test@groundx-helm-test.iam.gserviceaccount.com",' '  "token_uri": "https://oauth2.googleapis.com/token"' '}' > "$f"; created=1; fi; out=$("$HB" unittest -f tests/resources_test.yaml src/groundx 2>&1); rc=$?; if [ "$created" = 1 ]; then rm -f "$f"; rmdir src/groundx/files/ocr src/groundx/files 2>/dev/null; fi; if [ $rc -ne 0 ]; then printf '%s\n' "$out"; exit 1; fi; printf '%s' "$out" | grep -qE '^Tests:.*[1-9][0-9]* failed' && { echo "helm unittest exited 0 but its own summary reports a failure"; printf '%s\n' "$out"; exit 1; }; exit 0

## 2. Mirror identically into `helm/`

- [x] 2.1 Apply the same three edits from 1.1–1.3 (schema property, helper, rendered
      `config.py` line, `values.yaml` comment) into `helm/values.schema.json`,
      `helm/templates/_helpers/app/layout-ocr.tpl`, `helm/templates/resources/layout-config-py.yaml`,
      and `helm/values.yaml` — `helm/` has no `tests/` directory (removed in the mirror), so no
      snapshot task applies here.
      check: ${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0} template helm --set layout.ocr.timeout=187 --show-only templates/resources/layout-config-py.yaml 2>&1 | grep -c 'ocrTimeout=187,'

## 3. Regenerate snapshots and run the canonical gate

- [x] 3.1 Regenerate every `helm-unittest` golden snapshot the `layout-config-py` Secret's
      `config-hash` annotation touches, using the **pinned v3.19.0** binary only — never the
      ambient/unpinned `helm` (see the cross-cutting note above). The `config-hash` annotation at
      `templates/app/api.yaml:69`, `templates/app/celery.yaml:67`, and `templates/app/inference.yaml:71`
      hashes the rendered `layout-config-py.yaml` content, so adding `ocrTimeout` to that content
      changes the hash for every layout pod rendered in `api_test.yaml.snap`, `celery_test.yaml.snap`,
      and `inference_test.yaml.snap` — not only `resources_test.yaml.snap` (which renders
      `layout-config-py.yaml` directly and is the only file carrying the literal
      `ocrTimeout=120,` line). All four test files (like `resources_test.yaml`) need the same
      throwaway Google-OCR credential fixture at `src/groundx/files/ocr/gcv-test.json` present
      (the "packaged layout OCR credentials" GX-49 cases in `api`/`celery`/`inference_test.yaml`
      read it too) — use the same content as task 1.4's check, and remove it afterward the same
      way, or these runs error out for a reason unrelated to this change and the snapshot-index
      misalignment that follows can look like unrelated corruption.

      Use the human-approved **"Apply only regenerated lines"** method (design.md "Snapshot
      regeneration method"; the underlying plugin defect is tracked as GX-59) — never run `-u`
      against the worktree's committed snapshot files directly, and never hand-type a value into a
      committed snapshot:
      (a) Copy `src/groundx` to a scratch directory outside the worktree and run
      `helm unittest -u -f tests/resources_test.yaml -f tests/api_test.yaml -f tests/celery_test.yaml -f tests/inference_test.yaml <scratch-copy>`
      there (per-file `-u` invocations are fine too). Corruption in the scratch copy's `.snap`
      files is expected and harmless — it is discarded, never committed.
      (b) With a small throwaway script (not committed), extract from the scratch copy's
      regenerated `.snap` files only the new `ocrTimeout=<int>,` line and the new `config-hash`
      annotation values for the four affected snapshots.
      (c) Apply only those extracted line changes to the four **committed** snapshot files
      (`src/groundx/tests/__snapshot__/{resources,api,celery,inference}_test.yaml.snap`), so every
      other byte in each file stays identical to its base-branch content — no value typed by hand.
      (d) Verify byte-exact correctness by running the same
      `helm unittest -f tests/resources_test.yaml -f tests/api_test.yaml -f tests/celery_test.yaml -f tests/inference_test.yaml src/groundx`
      command **without** `-u` against the real worktree (pinned binary, OCR fixture present) and
      confirming it exits 0 — a plain run compares against the committed snapshot rather than
      rewriting it, and this revise pass confirmed that comparison is safe with the fixture
      present. Also run `.build/bin/verify-helm-snapshots.py` and `.build/bin/validate-helm.sh`.
      Diff the patched files against the base branch —
      `git diff -- src/groundx/tests/__snapshot__/{resources,api,celery,inference}_test.yaml.snap`
      — and confirm it touches only the new `ocrTimeout=<int>` line(s) and `config-hash`
      annotation **value** lines: no snapshot label dropped, added, reordered, or re-quoted, and no
      unrelated field injected. If it does, escalate rather than commit.
      (e) Commit all four snapshot files together in their own commit, separate from the
      schema/helper/template commit. The PR body states this method (scratch-regenerate,
      extract-only-changed-lines, patch) and cites GX-59.

      Delete the scratch copy and its throwaway extraction script before finishing this task —
      neither is committed and neither should remain in the worktree.
      check: HB="${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0}"; snaps="src/groundx/tests/__snapshot__/resources_test.yaml.snap src/groundx/tests/__snapshot__/api_test.yaml.snap src/groundx/tests/__snapshot__/celery_test.yaml.snap src/groundx/tests/__snapshot__/inference_test.yaml.snap"; f=src/groundx/files/ocr/gcv-test.json; created=0; if [ ! -e "$f" ]; then mkdir -p "$(dirname "$f")"; printf '%s\n' '{' '  "type": "service_account",' '  "project_id": "groundx-helm-test",' '  "private_key_id": "test",' '  "client_email": "test@groundx-helm-test.iam.gserviceaccount.com",' '  "token_uri": "https://oauth2.googleapis.com/token"' '}' > "$f"; created=1; fi; out=$("$HB" unittest -f tests/resources_test.yaml -f tests/api_test.yaml -f tests/celery_test.yaml -f tests/inference_test.yaml src/groundx 2>&1); rc=$?; if [ "$created" = 1 ]; then rm -f "$f"; rmdir src/groundx/files/ocr src/groundx/files 2>/dev/null; fi; if [ $rc -ne 0 ]; then printf '%s\n' "$out"; exit 1; fi; grep -q 'ocrTimeout=120,' src/groundx/tests/__snapshot__/resources_test.yaml.snap || { echo "resources snapshot missing ocrTimeout=120,"; exit 1; }; bad=$(git diff --unified=0 origin/0.2.7...HEAD -- $snaps | grep -E '^[+-][^+-]' | grep -vE '^[+-].*(ocrTimeout=[0-9]+,|config-hash: )'); [ -z "$bad" ] || { echo "snapshot diff touches lines beyond ocrTimeout/config-hash:"; printf '%s\n' "$bad"; exit 1; }
- [x] 3.2 Run the canonical gate, `.build/bin/validate-helm.sh`, with a real `python3` first on
      PATH (the bare `python` on this machine is a 2-line stub that silently skips 4 of its
      checks, including `verify-helm-snapshots.py`) and the pinned helm shimmed onto PATH as
      `helm` (mirrors `scripts/githooks/groundx-on-prem/pre-push`'s own shim pattern).
      check: h="${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0}"; d=$(mktemp -d); ln -s "$h" "$d/helm"; PATH="$d:$(dirname "$(command -v python3)"):$PATH" .build/bin/validate-helm.sh >/tmp/gx6-validate-helm.out 2>&1; rc=$?; rm -rf "$d"; exit $rc

## 4. Evidence (not committed tests — render matrix, src/helm parity, mutation proof)

- [x] 4.1 Render matrix: for `mode` in `{all, ingest}` × `layout.ocr.timeout` in
      `{unset, 187, 0, 251, 601}`, record whether the render succeeds and, if so, the rendered
      `ocrTimeout=` value — confirms `601` is rejected the same way `251` is (both exceed the
      ceiling). Also confirms `--set layout.ocr.timeout=120.0` and
      `--set-string layout.ocr.timeout=120.0` are **both rejected**: helm's `--set`/`--set-string`
      CLI flags parse an unquoted decimal like `120.0` as a **string**, not a float (observed
      directly against the pinned v3.19.0 binary: both flags produce
      `Error: ... at '/layout/ocr/timeout': got string, want integer`), so the integer-typed
      schema field rejects it either way — there is no accepted-CLI-float case for this field. A
      **values file** behaves differently: `layout: {ocr: {timeout: 120.0}}` written to a YAML
      file and passed via `-f` is parsed as a real YAML float, which the integer schema accepts (a
      float with no fractional part satisfies a JSON-Schema `integer` type) and renders
      `ocrTimeout=120,` — observed directly. Never print full rendered manifests; grep specific
      keys only. Record the matrix results in the PR description, not a committed file.
      check: HB="${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0}"; set -o pipefail; for m in all ingest; do for v in 187 0 251 601; do "$HB" template src/groundx --set mode=$m --set layout.ocr.timeout=$v >/dev/null 2>&1; rc=$?; if [ "$v" = "187" ]; then [ $rc -eq 0 ] || { echo "matrix mismatch: mode=$m timeout=$v rc=$rc (expected accept)"; exit 1; }; else [ $rc -ne 0 ] || { echo "matrix mismatch: mode=$m timeout=$v rc=$rc (expected reject)"; exit 1; }; fi; done; done; "$HB" template src/groundx --set layout.ocr.timeout=120.0 >/dev/null 2>&1 && { echo "unquoted --set 120.0 was wrongly accepted"; exit 1; }; "$HB" template src/groundx --set-string layout.ocr.timeout=120.0 >/dev/null 2>&1 && { echo "--set-string 120.0 was wrongly accepted"; exit 1; }; tf=$(mktemp); printf '%s\n' 'layout:' '  ocr:' '    timeout: 120.0' > "$tf"; out=$("$HB" template src/groundx -f "$tf" --show-only templates/resources/layout-config-py.yaml 2>&1); rc=$?; rm -f "$tf"; [ $rc -eq 0 ] || { echo "values-file float 120.0 render failed: $out"; exit 1; }; echo "$out" | grep -q 'ocrTimeout=120,' || { echo "values-file float 120.0 did not render ocrTimeout=120,: $out"; exit 1; }; echo ok
- [x] 4.2 `src`-vs-`helm` rendered-`config.py`-content parity: confirm the `ocrTimeout=` line
      rendered from `layout-config-py.yaml` matches between both trees under the same override
      (`layout.ocr.timeout=187`) — proves task 2.1 actually mirrored task 1.2 rather than
      drifting. Compares only that one line, not the whole rendered document: the pre-existing,
      out-of-scope `helm/Chart.yaml` version pin (`0.2.6` vs `src/groundx`'s `0.2.7`) makes every
      full-document render differ on chart/appVersion/label fields regardless of this change —
      confirmed directly (a whole-document diff on this override shows exactly that 4-line
      version/label delta and nothing else).
      check: HB="${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0}"; set -o pipefail; a=$("$HB" template src/groundx --set layout.ocr.timeout=187 --show-only templates/resources/layout-config-py.yaml 2>&1); ra=$?; b=$("$HB" template helm --set layout.ocr.timeout=187 --show-only templates/resources/layout-config-py.yaml 2>&1); rb=$?; if [ $ra -ne 0 ] || [ $rb -ne 0 ]; then echo "one or both renders failed (src rc=$ra, helm rc=$rb)"; exit 1; fi; la=$(echo "$a" | grep 'ocrTimeout='); lb=$(echo "$b" | grep 'ocrTimeout='); echo "$la" | grep -q 'ocrTimeout=187,' || { echo "src render missing ocrTimeout=187,"; exit 1; }; echo "$lb" | grep -q 'ocrTimeout=187,' || { echo "helm render missing ocrTimeout=187,"; exit 1; }; diff <(printf '%s\n' "$la") <(printf '%s\n' "$lb")
- [x] 4.3 Mutation proof: temporarily change the helper's default from `120` to `121` (or the
      schema `maximum` from `250` to `249`), re-run the two committed tests from 1.4, confirm they
      now fail (proving the tests actually exercise the code rather than passing vacuously), then
      revert the mutation before committing anything.
      check: HB="${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0}"; f=src/groundx/files/ocr/gcv-test.json; created=0; if [ ! -e "$f" ]; then mkdir -p "$(dirname "$f")"; printf '%s\n' '{' '  "type": "service_account",' '  "project_id": "groundx-helm-test",' '  "private_key_id": "test",' '  "client_email": "test@groundx-helm-test.iam.gserviceaccount.com",' '  "token_uri": "https://oauth2.googleapis.com/token"' '}' > "$f"; created=1; fi; base=$("$HB" unittest -f tests/resources_test.yaml src/groundx 2>&1); rb=$?; sed -i.bak 's/dig "timeout" 120 \$in/dig "timeout" 121 $in/' src/groundx/templates/_helpers/app/layout-ocr.tpl; mut=$("$HB" unittest -f tests/resources_test.yaml src/groundx 2>&1); rm_rc=$?; mv src/groundx/templates/_helpers/app/layout-ocr.tpl.bak src/groundx/templates/_helpers/app/layout-ocr.tpl; if [ "$created" = 1 ]; then rm -f "$f"; rmdir src/groundx/files/ocr src/groundx/files 2>/dev/null; fi; if [ $rb -ne 0 ]; then echo "unmutated committed resources_test.yaml cases must pass first"; exit 1; fi; if [ $rm_rc -eq 0 ]; then echo "mutating the helper default did not make the committed cases fail"; exit 1; fi; exit 0

---
Rollout: this is a single-repo, single-commit-group change (no expand/contract needed — a purely
additive field). No cross-service coordination task belongs in this file; see the workspace-level
`proposal.md` for this ticket (outside this repo, under the ticket's workspace
`openspec/changes/<change>/` directory) for the `groundx-studio-harness` documentation follow-on
(Level 2, merges only after the `0.2.7` release) and the FX-vendoring note (merging to `0.2.7`
does not reach Fraud-X prod until they re-vendor).
