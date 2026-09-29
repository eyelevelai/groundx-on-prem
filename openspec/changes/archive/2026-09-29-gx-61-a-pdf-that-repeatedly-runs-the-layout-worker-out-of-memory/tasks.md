Cross-cutting note: every `helm unittest`/`helm template` check below MUST use the pinned
`v3.19.0` binary via `${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0}` — fail
loudly if the variable is unset rather than silently falling back to the ambient `helm` (this
authoring pass confirmed the ambient local `helm v4.2.2` is not the pinned binary; per `AGENTS.md`
and the GX-6 design record, an unpinned `helm unittest -u` run has previously rewritten committed
snapshot content on this repo's suite). Every check also needs `yq` (mikefarah v4 line, already a
repo dependency for `verify-probe-mirror-drift.sh`) on `PATH`. If any check below leaves
`celery_test.yaml.snap` modified in a way not asserted by its own task, run
`git checkout -- src/groundx/tests/__snapshot__/celery_test.yaml.snap` before continuing.

**Mutation safety (2026-09-29 RED-baseline finding):** a plain (`-u`-less) `helm unittest`
invocation against this worktree's tracked `src/groundx`/`helm` trees was observed rewriting
`src/groundx/tests/__snapshot__/celery_test.yaml.snap` (dropped a snapshot label, renamed
another) — the GX-59 label defect, apparently reachable without `-u` too. Every `helm unittest`
invocation below (tasks 2.1, 2.2, 3.1, 4.2) and the mutation proof (task 5.1) therefore run
against a **scratch copy** of the chart (`d=$(mktemp -d); cp -R src/groundx "$d"/groundx` or the
`helm/` equivalent) and never against the tracked tree directly, and each ends by asserting
`git diff --quiet -- src/groundx/tests/__snapshot__ helm/tests/__snapshot__` so a mutation is
caught immediately rather than silently committed. `helm template`/`helm lint` are read-only
(they write nothing) and are exempt from this — they run directly against `src/groundx`/`helm` as
before. Task 5.3 still invokes `.build/bin/validate-helm.sh` directly against the real trees
unchanged — it is this repo's one sanctioned executable gate script (`AGENTS.md`) and its own
internal `helm unittest` calls are the same canonical-gate invocation CI already runs on every
push; redesigning it around a scratch copy is out of scope here (it also ends in `git diff
--check`, which needs a real git working tree). `celery_test.yaml` also carries a pre-existing,
unrelated `it:` case (`"legacy OCR credentials override the shared source"`) that needs
`files/ocr/gcv-test.json` to exist under the chart root or the whole suite errors with
`layout.ocr.credentials file not found` (this is the same throwaway fixture
`.build/bin/validate-helm.sh` generates for the real trees — see its header comment); every
scratch-copy check below that runs the full `celery_test.yaml` suite (2.1, 2.2, 3.1, 5.1) writes
this exact fixture content into the scratch copy first — using the validate-helm.sh's own
byte-for-byte JSON, since the fixture's content is itself hashed into a snapshot-covered
`ocr-credentials-hash` annotation and a differently-formatted JSON produces a different hash and
a spurious snapshot mismatch.

Constants used throughout: mount path `/tmp/render`, volume name `render-temp`, env vars `TMPDIR`
and `LAYOUT_RENDER_DISK_BUDGET_MIB`, schema property `layout.process.renderDiskBudgetMi` (integer,
minimum 1, default 2048). At the chart's defaults (1 worker × 1 thread × 2048 MiB budget + 1024 MiB
reserve), the computed `emptyDir.sizeLimit` / `resources.requests["ephemeral-storage"]` is
`3072Mi`.

## 1. Wire the render-disk volume, env, and disk-budget resources request end-to-end in `src/groundx` (thin vertical slice)

- [x] 1.1 Add `layout.process.renderDiskBudgetMi` to `src/groundx/values.schema.json`'s
      `layout.process` block: `"renderDiskBudgetMi": { "type": "integer", "minimum": 1 }`,
      inserted between the existing `"queue"` (line 1040) and `"replicas"` (line 1041)
      properties, matching the alphabetical sibling ordering already used in that block (and the
      GX-6 precedent for inserting a new bounded integer field alphabetically).
      check: ${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0} template src/groundx --set layout.process.renderDiskBudgetMi=0 2>&1 | grep -c "layout/process/renderDiskBudgetMi.*minimum: got 0, want 1"

- [x] 1.2 Add the `groundx.layout.process.renderDiskBudgetMi` helper to
      `src/groundx/templates/_helpers/app/layout-process.tpl` (`dig "renderDiskBudgetMi" 2048
      $in`, the same shape as the sibling `groundx.layout.process.batchSize` helper already in
      this file). In `groundx.layout.process.settings`, add `env` (`TMPDIR` = `/tmp/render`,
      `LAYOUT_RENDER_DISK_BUDGET_MIB` = the helper's value as a string) and `volumes` /
      `volumeMounts` (one `render-temp` `emptyDir` volume — no `medium` key, so it renders
      disk-backed — mounted at `/tmp/render`) unconditionally into `$cfg` (not gated behind a
      `hasKey $in "..."` check like the optional `affinity`/`labels`/etc. keys, since every
      `layout-process` pod gets this volume regardless of what the operator sets).
      `templates/app/celery.yaml` needs no change — it already renders any `env`/`volumes`/
      `volumeMounts` a service's `.settings` helper supplies (`celery.yaml:27-39,140-146,171-175,
      206-224`).
      check: HB="${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0}"; doc=$("$HB" template src/groundx --show-only templates/app/celery.yaml 2>&1 | yq eval-all 'select(.metadata.name == "layout-process")' -) || exit 1; echo "$doc" | yq eval '.spec.template.spec.containers[0].env[] | select(.name == "TMPDIR") | .value' - | grep -qx '/tmp/render' || { echo "TMPDIR missing or wrong: $doc"; exit 1; }; echo "$doc" | yq eval '.spec.template.spec.containers[0].env[] | select(.name == "LAYOUT_RENDER_DISK_BUDGET_MIB") | .value' - | grep -qx '2048' || { echo "budget env missing or wrong: $doc"; exit 1; }; echo "$doc" | yq eval '.spec.template.spec.volumes[] | select(.name == "render-temp")' - | grep -qx 'emptyDir:' || { echo "render-temp volume missing: $doc"; exit 1; }; echo "$doc" | yq eval '.spec.template.spec.volumes[] | select(.name == "render-temp") | .emptyDir.sizeLimit' - | grep -qx '3072Mi' || { echo "sizeLimit missing or wrong: $doc"; exit 1; }; echo "$doc" | yq eval '.spec.template.spec.volumes[] | select(.name == "render-temp") | has("medium")' - | grep -qx 'false' || { echo "render-temp volume must not set medium (must stay disk-backed): $doc"; exit 1; }; echo "$doc" | yq eval '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "render-temp") | .mountPath' - | grep -qx '/tmp/render' || { echo "volumeMount missing or wrong: $doc"; exit 1; }; echo ok

- [x] 1.3 In the same `groundx.layout.process.settings` helper, replace the existing conditional
      `resources` assignment (`{{- if and (hasKey $in "resources") (not (empty (get $in
      "resources"))) -}} {{- $_ := set $cfg "resources" (get $in "resources") -}} {{- end -}}`)
      with an unconditional merge that always renders `resources.requests["ephemeral-storage"]`:
      `deepCopy` the `resources` dict from `$in` (defaulting to an empty dict when absent — follow
      the `layout-inference.tpl:239` `deepCopy (get $in "resources")` precedent exactly, so
      `.Values.layout.process.resources` is never mutated), `deepCopy` its nested `requests` dict
      the same way, `set` `ephemeral-storage` on that copy to `workers × threads ×
      renderDiskBudgetMi + 1024` (formatted `<N>Mi`), then assign the copy back into `$cfg`
      unconditionally — so it always renders even when an operator sets no `resources` at all, and
      every other key under `resources` (`requests.cpu`, `requests.memory`, any `limits`) survives
      unchanged.
      check: HB="${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0}"; doc=$("$HB" template src/groundx --show-only templates/app/celery.yaml 2>&1 | yq eval-all 'select(.metadata.name == "layout-process")' -) || exit 1; req=$(echo "$doc" | yq eval '.spec.template.spec.containers[0].resources.requests' -); echo "$req" | grep -q '^cpu: 100m$' || { echo "cpu request missing/changed: $req"; exit 1; }; echo "$req" | grep -q '^memory: 1Gi$' || { echo "memory request missing/changed: $req"; exit 1; }; echo "$req" | grep -q 'ephemeral-storage: 3072Mi' || { echo "ephemeral-storage request missing: $req"; exit 1; }; echo ok

- [x] 1.4 Add a one-line comment directly above `process:` in `src/groundx/values.yaml` (around
      line 257) documenting the default budget and what it sizes (mirrors the existing
      `layout.ocr.timeout` comment convention immediately above `ocr:` in the same file) — no
      ticket ID, no narration, one line.
      check: n/a — comment-only documentation change, no rendered behavior to assert

- [x] 1.5 Confirm an override scales all three rendered fields (`sizeLimit`, the
      `ephemeral-storage` request, and the env value) together from the single
      `renderDiskBudgetMi` input, including when `workers` also changes — proves task 1.2/1.3's
      formula, not just its default-value path.
      check: HB="${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0}"; doc=$("$HB" template src/groundx --show-only templates/app/celery.yaml --set layout.process.renderDiskBudgetMi=4096 --set layout.process.workers=2 2>&1 | yq eval-all 'select(.metadata.name == "layout-process")' -) || exit 1; echo "$doc" | yq eval '.spec.template.spec.volumes[] | select(.name == "render-temp") | .emptyDir.sizeLimit' - | grep -qx '9216Mi' || { echo "sizeLimit did not scale: $doc"; exit 1; }; echo "$doc" | yq eval '.spec.template.spec.containers[0].resources.requests."ephemeral-storage"' - | grep -qx '9216Mi' || { echo "ephemeral-storage request did not scale: $doc"; exit 1; }; echo "$doc" | yq eval '.spec.template.spec.containers[0].env[] | select(.name == "LAYOUT_RENDER_DISK_BUDGET_MIB") | .value' - | grep -qx '4096' || { echo "budget env did not follow override: $doc"; exit 1; }; echo ok

- [x] 1.6 Confirm a user-supplied `ephemeral-storage` request is replaced by the chart-computed
      value while every other `resources.requests` key the user set survives unchanged (the
      deepCopy-merge behavior, not just the no-override default path).
      check: HB="${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0}"; doc=$("$HB" template src/groundx --show-only templates/app/celery.yaml --set layout.process.resources.requests.cpu=250m --set layout.process.resources.requests.memory=2Gi --set layout.process.resources.requests.ephemeral-storage=500Mi 2>&1 | yq eval-all 'select(.metadata.name == "layout-process")' -) || exit 1; req=$(echo "$doc" | yq eval '.spec.template.spec.containers[0].resources.requests' -); echo "$req" | grep -q '^cpu: 250m$' || { echo "cpu override lost: $req"; exit 1; }; echo "$req" | grep -q '^memory: 2Gi$' || { echo "memory override lost: $req"; exit 1; }; echo "$req" | grep -q 'ephemeral-storage: 3072Mi' || { echo "chart-computed ephemeral-storage did not win: $req"; exit 1; }; echo "$req" | grep -q '500Mi' && { echo "stale user-supplied ephemeral-storage leaked through: $req"; exit 1; }; echo ok

## 2. Extend `src/groundx/tests/celery_test.yaml` with discrete assertion cases

- [x] 2.1 Add four `it:` cases to `src/groundx/tests/celery_test.yaml` (immediately before the
      existing `"default: celery"` case, alongside the other non-snapshot assertion-style cases
      already in this file), each `documentSelector`-scoped to `metadata.name: layout-process`
      except the reject case (which asserts the whole release fails to render, so no document
      selector applies):
      1. "render-disk: layout-process gets the emptyDir volume, mount, and disk-budget env at
         chart defaults" — `contains` on `env` (both `TMPDIR` and `LAYOUT_RENDER_DISK_BUDGET_MIB`
         entries), `contains` on `volumes` (`render-temp` with `emptyDir.sizeLimit: 3072Mi`, no
         `medium` key), `contains` on `containers[0].volumeMounts` (`render-temp` at
         `/tmp/render`), and `equal` on `containers[0].resources.requests.ephemeral-storage:
         3072Mi`.
      2. "render-disk: an override scales sizeLimit, the ephemeral-storage request, and the
         budget env together" — `set: {layout.process.renderDiskBudgetMi: 4096,
         layout.process.workers: 2}`, asserting `9216Mi` in all three places (mirrors task 1.5).
      3. "render-disk: schema rejects a below-minimum renderDiskBudgetMi before any resource
         renders" — `set: {layout.process.renderDiskBudgetMi: 0}`, `asserts: [{failedTemplate:
         {errorPattern: "layout/process/renderDiskBudgetMi.*minimum.*got 0, want 1"}}]` (no
         `documentSelector` — the whole release fails to render).
      4. "render-disk: a user-supplied ephemeral-storage request is replaced, other resources
         keys survive" — `set` the same three overrides as task 1.6, `equal` on
         `containers[0].resources.requests` against the exact expected map (`cpu: 250m, memory:
         2Gi, ephemeral-storage: 3072Mi`).
      check: HB="${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0}"; d=$(mktemp -d); cp -R src/groundx "$d"/groundx; mkdir -p "$d/groundx/files/ocr"; printf '%s\n' '{' '  "type": "service_account",' '  "project_id": "groundx-helm-test",' '  "private_key_id": "test",' '  "client_email": "test@groundx-helm-test.iam.gserviceaccount.com",' '  "token_uri": "https://oauth2.googleapis.com/token"' '}' > "$d/groundx/files/ocr/gcv-test.json"; j=$(mktemp -d); "$HB" unittest -f tests/celery_test.yaml -o junit --output-file "$j/out.xml" "$d/groundx" >/tmp/gx61-celery-unittest.out 2>&1; rc=$?; rm -rf "$d"; git diff --quiet -- src/groundx/tests/__snapshot__ helm/tests/__snapshot__ || { rm -rf "$j"; echo "worktree snapshot mutated by a scratch-copy check"; exit 1; }; if [ $rc -ne 0 ]; then cat /tmp/gx61-celery-unittest.out; rm -rf "$j"; exit 1; fi; fail=0; for name in "render-disk: layout-process gets the emptyDir volume, mount, and disk-budget env at chart defaults" "render-disk: an override scales sizeLimit, the ephemeral-storage request, and the budget env together" "render-disk: schema rejects a below-minimum renderDiskBudgetMi before any resource renders" "render-disk: a user-supplied ephemeral-storage request is replaced, other resources keys survive"; do grep -F "name=\"$name\"" "$j/out.xml" | grep -q 'result="Pass"' || { echo "missing or failing case: $name"; fail=1; }; done; rm -rf "$j"; [ "$fail" -eq 0 ] || exit 1; exit 0

- [x] 2.2 Add one `it:` case titled exactly `"render-disk: the emptyDir volume stays per-pod
      under multiple replicas, not shared or bound"` asserting the render-temp volume stays
      per-pod and adds no shared/bound storage under multiple replicas — `set:
      {layout.process.replicas.desired: 3}`, scoped to `layout-process`, asserting `spec.replicas:
      3`, `isKind: {of: Deployment}` (not converted to a `StatefulSet`), and the same `render-temp`
      `emptyDir` `contains` assertion as case 1 above (proves the volume shape is independent of
      replica count — one `emptyDir` per pod template, not a per-replica-indexed list).
      check: HB="${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0}"; d=$(mktemp -d); cp -R src/groundx "$d"/groundx; mkdir -p "$d/groundx/files/ocr"; printf '%s\n' '{' '  "type": "service_account",' '  "project_id": "groundx-helm-test",' '  "private_key_id": "test",' '  "client_email": "test@groundx-helm-test.iam.gserviceaccount.com",' '  "token_uri": "https://oauth2.googleapis.com/token"' '}' > "$d/groundx/files/ocr/gcv-test.json"; j=$(mktemp -d); "$HB" unittest -f tests/celery_test.yaml -o junit --output-file "$j/out.xml" "$d/groundx" >/tmp/gx61-celery-unittest-2.out 2>&1; rc=$?; rm -rf "$d"; git diff --quiet -- src/groundx/tests/__snapshot__ helm/tests/__snapshot__ || { rm -rf "$j"; echo "worktree snapshot mutated by a scratch-copy check"; exit 1; }; if [ $rc -ne 0 ]; then cat /tmp/gx61-celery-unittest-2.out; rm -rf "$j"; exit 1; fi; name="render-disk: the emptyDir volume stays per-pod under multiple replicas, not shared or bound"; ok=0; grep -F "name=\"$name\"" "$j/out.xml" | grep -q 'result="Pass"' && ok=1; rm -rf "$j"; [ "$ok" -eq 1 ] || { echo "missing or failing case: $name"; exit 1; }; exit 0

## 3. Hand-patch `src/groundx/tests/__snapshot__/celery_test.yaml.snap`'s 12 `layout-process` blocks

- [x] 3.1 (corrected during implementation — see the `implementation note` below) `layout-process`
      renders inside 13 of `celery_test.yaml`'s `matchSnapshot` blocks — `'aws: celery'`,
      `'cloud: celery'`, `'default: celery'`, `'empty: celery'`, `'existing: celery'`,
      `'extract: celery'`, `'extract.ingest: celery'`, `'extract.oai: celery'`,
      `'metadata: celery'`, `'minikube: celery'`, `'openshift: celery'`, `'phoenix: celery'`, and
      `'shared Google credentials: celery'`. The `'disabled: celery'` and
      `'workspace-enabled: celery'` blocks set `layout.process.enabled: false` (directly, or via
      the `values.disabled.yaml` base `workspace-enabled: celery` layers on top of) and render no
      `layout-process`/renamed-process Deployment at all — those two are unaffected.
      **Implementation note (corrects this task's original premise):** a literal grep for
      `name: layout-process` finds exactly 24 occurrences (2 per block × 12 blocks) and was
      mistaken for the complete set — but `'metadata: celery'` renders the same
      `groundx.layout.process.settings` pod under a renamed container (`name: myapp-process`, via
      that test's `layout.serviceName: myapp` override in `values.metadata.yaml`), so it needs the
      identical patch and was missing from the original 12-block list (which incorrectly listed
      `'workspace-enabled: celery'` instead — that block's `layout.process` stays disabled from its
      `values.disabled.yaml` base, confirmed by `layout.process.enabled: false` there and no
      re-enable in `values.workspace.enabled.yaml`, so it renders no such Deployment and was wrongly
      included). `values.metadata.yaml` also overrides `layout.process.workers: 2` and
      `layout.process.threads: 2` (contradicting this task's original "no test values file
      overrides workers/threads/renderDiskBudgetMi" premise), so its budget renders as `9216Mi`
      (`2 × 2 × 2048 + 1024`) — the only one of the 13 blocks that is not the `3072Mi` default;
      the other 12 all render the identical default-budget shape: two new `env` entries
      (`LAYOUT_RENDER_DISK_BUDGET_MIB` then `TMPDIR`, alphabetical — the range over the `env` dict
      sorts by key), one new `resources.requests.ephemeral-storage` line (alphabetically
      positioned among the existing `requests` keys; `3072Mi` for 12 blocks, `9216Mi` for
      `'metadata: celery'`), one new `render-temp` entry appended to that block's `volumeMounts`
      list, and one new `render-temp` entry appended to that block's `volumes` list. No block's
      `config-hash` annotation changes — that hash covers `layout-config-py.yaml` (the shared
      config Secret), which this change does not touch.

      Follow the same **"Apply only regenerated lines"** method the GX-6 design record used (its
      underlying cause — the installed `helm-unittest` v1.1.2 plugin drops/reorders unrelated
      snapshot labels on `-u` regeneration — is tracked as GX-59 and is unrelated to this change;
      never run `-u` against the worktree's committed snapshot file directly, and never hand-type
      a value into a committed snapshot):
      (a) Copy `src/groundx` to a scratch directory outside the worktree and run
      `helm unittest -u -f tests/celery_test.yaml <scratch-copy>` there with the **pinned**
      binary. Corruption in the scratch copy is expected and harmless — it is discarded, never
      committed.
      (b) With a small throwaway script (not committed), extract from the scratch copy's
      regenerated `celery_test.yaml.snap` only the new lines this task describes (the two `env`
      entries, the `ephemeral-storage` line, and the two `render-temp` volume/volumeMount blocks)
      for each of the 12 affected snapshot indices.
      (c) Apply only those extracted line insertions to the **committed**
      `src/groundx/tests/__snapshot__/celery_test.yaml.snap`, so every other byte in the file
      stays identical to its base-branch content — no snapshot label dropped, added, reordered, or
      re-quoted, and no unrelated field injected.
      (d) Verify byte-exact correctness with a **plain** (`-u`-less)
      `helm unittest -f tests/celery_test.yaml <fresh-scratch-copy-of-src/groundx>` (pinned
      binary) — copy the now-patched `src/groundx` to a second, fresh scratch directory first and
      run there, never directly against the real worktree: a plain run compares against the
      committed snapshot rather than rewriting it, but this repo's `helm-unittest` has been
      observed rewriting the committed snapshot even on a plain run (task list's Mutation safety
      note above), so even this verification step must not touch the tracked file directly.
      Confirm it exits 0, then confirm `git diff --quiet -- src/groundx/tests/__snapshot__` on the
      real worktree to prove the verification itself left the committed file untouched.
      (e) Diff the patched file against `origin/0.2.7` and confirm every added line matches one of
      the expected shapes and **no line is removed**: no dropped snapshot label, no reordering, no
      unrelated content. Commit this snapshot file in its own commit, separate from the
      schema/helper/template commit; the PR body states this method and cites GX-59.
      Delete the scratch copy and its throwaway extraction script before finishing this task.
      check: HB="${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0}"; d=$(mktemp -d); cp -R src/groundx "$d"/groundx; mkdir -p "$d/groundx/files/ocr"; printf '%s\n' '{' '  "type": "service_account",' '  "project_id": "groundx-helm-test",' '  "private_key_id": "test",' '  "client_email": "test@groundx-helm-test.iam.gserviceaccount.com",' '  "token_uri": "https://oauth2.googleapis.com/token"' '}' > "$d/groundx/files/ocr/gcv-test.json"; out=$("$HB" unittest -f tests/celery_test.yaml "$d/groundx" 2>&1); rc=$?; rm -rf "$d"; git diff --quiet -- src/groundx/tests/__snapshot__ helm/tests/__snapshot__ || { echo "worktree snapshot mutated by a scratch-copy check"; exit 1; }; if [ $rc -ne 0 ]; then printf '%s\n' "$out"; exit 1; fi; grep -q 'ephemeral-storage: 3072Mi' src/groundx/tests/__snapshot__/celery_test.yaml.snap || { echo "snapshot missing ephemeral-storage: 3072Mi"; exit 1; }; [ "$(grep -c 'ephemeral-storage: 3072Mi' src/groundx/tests/__snapshot__/celery_test.yaml.snap)" -eq 12 ] || { echo "expected exactly 12 default-budget (3072Mi) blocks plus the 'metadata: celery' 9216Mi block (13 total)"; exit 1; }; grep -q 'ephemeral-storage: 9216Mi' src/groundx/tests/__snapshot__/celery_test.yaml.snap || { echo "snapshot missing the 'metadata: celery' 9216Mi block (layout.process.workers/threads overridden to 2 there)"; exit 1; }; bad=$(git diff --unified=0 origin/0.2.7...HEAD -- src/groundx/tests/__snapshot__/celery_test.yaml.snap | grep -E '^-[^-]'); [ -z "$bad" ] || { echo "snapshot diff removed a line — expected additions only:"; printf '%s\n' "$bad"; exit 1; }; added=$(git diff --unified=0 origin/0.2.7...HEAD -- src/groundx/tests/__snapshot__/celery_test.yaml.snap | grep -E '^\+[^+]'); bad2=$(printf '%s\n' "$added" | grep -vE '^\+\s*(- name: render-temp|- emptyDir:|emptyDir:|sizeLimit: [0-9]+Mi|- mountPath: /tmp/render|name: render-temp|- name: (TMPDIR|LAYOUT_RENDER_DISK_BUDGET_MIB)|value: "?(/tmp/render|[0-9]+)"?|ephemeral-storage: [0-9]+Mi)\s*$'); [ -z "$bad2" ] || { echo "snapshot diff added a line outside the expected shapes:"; printf '%s\n' "$bad2"; exit 1; }; exit 0

## 4. Mirror into `helm/`

- [x] 4.1 Apply the same edits from 1.1–1.4 into `helm/values.schema.json` (same insertion
      point), `helm/templates/_helpers/app/layout-process.tpl` (confirmed byte-identical to
      `src/groundx`'s copy today, so this is a plain copy of the same diff, not a drift
      reconciliation), and `helm/values.yaml`. `helm/templates/app/celery.yaml` needs no change,
      same reasoning as task 1.2.
      check: HB="${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0}"; doc=$("$HB" template helm --show-only templates/app/celery.yaml 2>&1 | yq eval-all 'select(.metadata.name == "layout-process")' -) || exit 1; echo "$doc" | yq eval '.spec.template.spec.containers[0].env[] | select(.name == "TMPDIR") | .value' - | grep -qx '/tmp/render' || { echo "helm/ mirror missing TMPDIR: $doc"; exit 1; }; echo "$doc" | yq eval '.spec.template.spec.containers[0].resources.requests."ephemeral-storage"' - | grep -qx '3072Mi' || { echo "helm/ mirror missing ephemeral-storage request: $doc"; exit 1; }; echo ok

- [x] 4.2 Add `helm/tests/layout_process_render_disk_test.yaml` (mirrors the
      `helm/tests/layout_ocr_timeout_test.yaml` GX-6 precedent — no `chart:` override, no
      `values:` override, just `templates:`/`set:`/`asserts:`) with two cases: the default-budget
      case (env, volume, and resources assertions from task 2.1 case 1) and an override case
      (`renderDiskBudgetMi: 4096` renders `5120Mi` in `sizeLimit` and the ephemeral-storage
      request at 1 worker × 1 thread), so `validate-helm.sh`'s existing `helm unittest helm` step
      fails if the mirror drifts from `src/groundx`.
      check: HB="${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0}"; test -f helm/tests/layout_process_render_disk_test.yaml || { echo "helm/tests/layout_process_render_disk_test.yaml missing"; exit 1; }; d=$(mktemp -d); cp -R helm "$d"/helm; j=$(mktemp -d); "$HB" unittest -f tests/layout_process_render_disk_test.yaml -o junit --output-file "$j/out.xml" "$d/helm" >/tmp/gx61-render-disk-unittest.out 2>&1; rc=$?; rm -rf "$d"; git diff --quiet -- src/groundx/tests/__snapshot__ helm/tests/__snapshot__ || { rm -rf "$j"; echo "worktree snapshot mutated by a scratch-copy check"; exit 1; }; if [ $rc -ne 0 ]; then cat /tmp/gx61-render-disk-unittest.out; rm -rf "$j"; exit 1; fi; n=$(grep -oE '<test name=' "$j/out.xml" | wc -l | tr -d ' '); rm -rf "$j"; [ "$n" -ge 2 ] || { echo "expected at least 2 test cases (default + override) from layout_process_render_disk_test.yaml, saw $n"; exit 1; }; exit 0

## 5. Evidence (not committed tests — mutation proof, src/helm parity, canonical gate)

- [x] 5.1 Mutation proof: temporarily change the helper's default from `2048` to `2049` (or the
      schema `minimum` from `1` to `0`), re-run the four new cases from task 2.1, confirm at least
      one now fails (proving the tests actually exercise the code rather than passing vacuously),
      then revert the mutation before committing anything.
      check: HB="${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0}"; d=$(mktemp -d); cp -R src/groundx "$d"/groundx; mkdir -p "$d/groundx/files/ocr"; printf '%s\n' '{' '  "type": "service_account",' '  "project_id": "groundx-helm-test",' '  "private_key_id": "test",' '  "client_email": "test@groundx-helm-test.iam.gserviceaccount.com",' '  "token_uri": "https://oauth2.googleapis.com/token"' '}' > "$d/groundx/files/ocr/gcv-test.json"; base=$("$HB" unittest -f tests/celery_test.yaml "$d/groundx" 2>&1); rb=$?; sed -i.bak 's/dig "renderDiskBudgetMi" 2048 \$in/dig "renderDiskBudgetMi" 2049 $in/' "$d/groundx/templates/_helpers/app/layout-process.tpl"; mut=$("$HB" unittest -f tests/celery_test.yaml "$d/groundx" 2>&1); rm_rc=$?; rm -rf "$d"; git diff --quiet -- src/groundx/tests/__snapshot__ helm/tests/__snapshot__ || { echo "worktree snapshot mutated by a scratch-copy check"; exit 1; }; git diff --quiet -- src/groundx/templates/_helpers/app/layout-process.tpl || { echo "worktree helper template mutated by the mutation-proof check"; exit 1; }; if [ $rb -ne 0 ]; then echo "unmutated committed celery_test.yaml cases must pass first"; exit 1; fi; if [ $rm_rc -eq 0 ]; then echo "mutating the helper default did not make any committed case fail"; exit 1; fi; exit 0

- [x] 5.2 `src`-vs-`helm` rendered-content parity: confirm the `env`/`volumes`/`resources` fields
      rendered from `layout-process.tpl` match between both trees under the same override
      (`layout.process.renderDiskBudgetMi=4096`) — proves task 4.1 actually mirrored tasks 1.2–1.3
      rather than drifting. Compares only those fields, not the whole rendered document (the
      pre-existing, out-of-scope `helm/Chart.yaml` version pin makes a whole-document diff differ
      on chart/appVersion/label fields regardless of this change).
      check: HB="${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0}"; render() { "$HB" template "$1" --show-only templates/app/celery.yaml --set layout.process.renderDiskBudgetMi=4096 2>&1 | yq eval-all 'select(.metadata.name == "layout-process")' -; }; src_doc=$(render src/groundx); helm_doc=$(render helm); fail() { echo "$1"; exit 1; }; for field in '.spec.template.spec.containers[0].env[] | select(.name == "TMPDIR") | .value' '.spec.template.spec.containers[0].env[] | select(.name == "LAYOUT_RENDER_DISK_BUDGET_MIB") | .value' '.spec.template.spec.volumes[] | select(.name == "render-temp") | .emptyDir.sizeLimit' '.spec.template.spec.containers[0].resources.requests."ephemeral-storage"'; do av=$(echo "$src_doc" | yq eval "$field" -); bv=$(echo "$helm_doc" | yq eval "$field" -); { [ -n "$av" ] && [ "$av" != "null" ]; } || fail "src/groundx missing/empty for: $field"; { [ -n "$bv" ] && [ "$bv" != "null" ]; } || fail "helm missing/empty for: $field"; [ "$av" = "$bv" ] || fail "src ($av) and helm ($bv) diverge for: $field"; done; echo ok

- [x] 5.3 Run the canonical gate, `.build/bin/validate-helm.sh`, with a real `python3` first on
      PATH (the bare `python` on some machines is a stub that silently skips several checks
      including `verify-helm-snapshots.py`) and the pinned helm shimmed onto PATH as `helm`
      (mirrors `scripts/githooks/groundx-on-prem/pre-push`'s own shim pattern). This repo's
      `AGENTS.md` marks `.build/bin/validate-helm.sh` itself as the one script this Tier 3
      privileged repo's read/template/lint/unittest-only constraint permits executing.
      check: h="${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0}"; d=$(mktemp -d); ln -s "$h" "$d/helm"; PATH="$d:$(dirname "$(command -v python3)"):$PATH" .build/bin/validate-helm.sh >/tmp/gx61-validate-helm.out 2>&1; rc=$?; rm -rf "$d"; if [ $rc -ne 0 ]; then cat /tmp/gx61-validate-helm.out; exit $rc; fi; doc=$("$h" template src/groundx --show-only templates/app/celery.yaml 2>&1 | yq eval-all 'select(.metadata.name == "layout-process")' -); v=$(echo "$doc" | yq eval '.spec.template.spec.containers[0].resources.requests."ephemeral-storage"' -); { [ -n "$v" ] && [ "$v" != "null" ]; } || { echo "the canonical gate passed but ephemeral-storage is still absent from the src/groundx render — the gate alone does not exercise this feature"; exit 1; }; exit 0

---
Rollout: this is a single-repo, additive, schema-optional change — no expand/contract needed. It
rolls out as one `layout-process`-only rolling restart on the first `helm upgrade` that includes it
(every replica's env/volume/resources change once, even at the default budget; every other layout
workload — `api`, `correct`, `inference`, `map`, `ocr`, `save` — is untouched). Sequence:

1. This PR and `ai-server`'s companion PR (same ticket, separate repo) can merge in either order
   (see `design.md`'s backward-compatibility decisions) — but the PR body must state "chart-first
   or together" so an operator upgrading only the `ai-server` image without this chart change
   knows the disk-render path falls back to `ai-server`'s own default temp directory and budget,
   not an error.
2. This PR's merge to `0.2.7` does **not** publish the chart — publishing (`Chart.yaml` version
   bump, `src/build.sh`) is a separate, maintainer-only, human-run release step (see `design.md`'s
   "Chart version and publish convention" decision), and Fraud-X's pinned vendored commit does not
   move until they re-vendor.
3. `groundx-studio-harness` documentation (`values-yaml.md`, `cluster-requirements.md`,
   `failure-modes.md`, `troubleshooting.md`) is Level 2 for this ticket — out of scope for this
   repo and this proposal, gated to merge only after the patched `0.2.7` chart is published, per
   the GX-6 precedent.
4. Sequencing note for the open, unrelated PR #119 (GX-22, `gx-22-on-prem-helm-unittest-toolchain-pin-0.2.7`):
   see `design.md`'s dedicated decision — no content collision on `celery_test.yaml.snap`, merge
   either order, no rebase-conflict expected.

See the workspace-level `openspec/changes/<change>/tasks.md` (outside this repo, under this
ticket's workspace change directory) for cross-service coordination and any deferred follow-up
items (the `layout.process.batchSize`/GX-7/FRA-150 items out of scope for GX-61).

## Amendments

### 2026-09-29 — review round 1 fix (G1, G2, G3, G4)

- [x] 6.1 Add the `groundx.layout.process.storageMi` helper (parses a Kubernetes storage quantity
      to MiB; `fail`s on an unrecognized format) and a guard in `groundx.layout.process.settings`
      that fails template rendering when `layout.process.resources.limits["ephemeral-storage"]` is
      set below the computed request, naming `layout.process.renderDiskBudgetMi` and the offending
      limit. Mirror into `helm/`.
      check: ${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0} template src/groundx --set layout.process.resources.limits.ephemeral-storage=1Gi 2>&1 | grep -c 'layout.process.resources.limits\["ephemeral-storage"\].*1Gi.*below the computed ephemeral-storage request of 3072Mi'
- [x] 6.2 Add a guard in `groundx.layout.process.settings` that fails template rendering when
      `layout.process.workers` or `layout.process.threads` is below 1, naming the offending field
      and value. Template-scoped to `layout.process`, not a shared schema `minimum` (see
      `design.md` Amendments). Mirror into `helm/`.
      check: ${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0} template src/groundx --set layout.process.workers=-1 2>&1 | grep -c 'layout.process.workers must be at least 1 (got -1)'
- [x] 6.3 Add unittest cases for 6.1/6.2 (reject below-request limit, reject negative
      workers/threads, and a "limit at or above the computed request renders unchanged" must-not-block
      case) to `src/groundx/tests/celery_test.yaml` and `helm/tests/layout_process_render_disk_test.yaml`;
      confirm each reject case fails on the pre-round code (RED) via a scratch copy of the pre-fix
      `layout-process.tpl` and passes post-fix.
      check: HB="${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0}"; d=$(mktemp -d); cp -R src/groundx "$d"/groundx; mkdir -p "$d/groundx/files/ocr"; printf '%s\n' '{' '  "type": "service_account",' '  "project_id": "groundx-helm-test",' '  "private_key_id": "test",' '  "client_email": "test@groundx-helm-test.iam.gserviceaccount.com",' '  "token_uri": "https://oauth2.googleapis.com/token"' '}' > "$d/groundx/files/ocr/gcv-test.json"; out=$("$HB" unittest -f tests/celery_test.yaml "$d/groundx" 2>&1); rc=$?; rm -rf "$d"; git diff --quiet -- src/groundx/tests/__snapshot__ helm/tests/__snapshot__ || { echo "worktree snapshot mutated by a scratch-copy check"; exit 1; }; [ $rc -eq 0 ] || { printf '%s\n' "$out"; exit 1; }; exit 0
- [x] 6.4 Extend the "the emptyDir volume stays per-pod under multiple replicas" test to also set
      `cluster.hpa: true` and assert the rendered `layout-process-hpa` HorizontalPodAutoscaler's
      `minReplicas`/`maxReplicas`, closing the previously-untested HPA half of the per-pod scenario
      (see `spec.md` Amendments for why `cluster.hpa`, not `layout.process.replicas.hpa`, is used).
      check: ${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to pinned helm v3.19.0} template src/groundx --set cluster.hpa=true --set layout.process.replicas.desired=3 --set layout.process.replicas.min=1 --set layout.process.replicas.max=6 --show-only templates/resources/hpa.yaml 2>&1 | grep -c "name: layout-process-hpa"
- [x] 6.5 Fix the ADR's self-contradictory restart wording (a container restart gives the new
      container a fresh writable layer; the dead container's own layer and its temp files stay on
      the node, invisible to the new container, until kubelet GC or pod deletion) and replace the
      unresolvable "comment thread C2-C7, confirmed by three spike reports" citation with the
      finding stated directly plus a link to GX-61.
      check: n/a — doc-only correction, no rendered behavior to assert
- [x] 6.6 Amend `specs/layout-process-render-disk/spec.md`, `design.md`, and this file with dated
      `## Amendments` sections (this change is already archived; the record-hygiene rule forbids
      silently rewriting an archived artifact's original text).
      check: n/a — record-hygiene/documentation task, no rendered behavior to assert
