## Tasks

Implementation runs through the ambient Superpowers loop — this list is artifact-specific only.

See the workspace `openspec/changes/gx-22-groundx-on-prem-helm-unittest-snapshot-for-celery-is-non/`
proposal for the full 22-helper scope table and the six already-safe `fromYaml` exclusions; both are
restated in `design.md` only where needed to write a task.

### Stage 0 — Proof gate (do this first; nothing below is unconditional)

This stage alone is a complete, shippable slice: it either confirms the mechanism and unblocks
Stage 1, or it produces the escalation evidence and the change stops here with only the gate tooling
landed.

- [x] 0.1 Reproduce the two-run drift on a clean base (helm off `PATH`; pin to v3.19.0 locally to
      match CI if available) and record the exact `git diff` of
      `src/groundx/tests/__snapshot__/celery_test.yaml.snap` across two successive
      `helm unittest src/groundx` runs. Do not assume the drifting entries match the ticket's list —
      record what actually changed.
      check: n/a — diagnostic reconnaissance, no code changed; its recorded output feeds task 0.2's
      attribution and is not itself a pass/fail condition.

      **Recorded result:** installed the CI-pinned `helm-unittest` plugin against a locally-fetched
      Helm v3.19.0 (matching `.github/workflows/helm-tests.yml`). Two successive
      `helm unittest -u src/groundx -f 'tests/celery_test.yaml'` runs on a clean base produced a
      **byte-identical** `celery_test.yaml.snap` (`diff` exit 0); repeated 15x in a row, same
      result every time. `git diff --stat` against the committed HEAD snapshot showed 202
      insertions / 203 deletions, but per-testcase block comparison (avoiding whole-file diff
      misalignment caused by one dropped line) shows every one of those lines is a
      `config-hash`/`supervisord-hash`/`gunicorn-conf-hash`/`config-models-hash` annotation value
      (sha256sum of an included resource sub-template) — never a replicas/HPA value, never a
      `secretRef` name or order. Root cause of that one-time HEAD-vs-local difference: `git ls-files
      --eol src/groundx/templates/resources/layout-config-py.yaml` shows `i/lf w/crlf` — this
      Windows checkout has no `.gitattributes` pinning template source files to LF, so the local
      working tree's line endings differ from the committed LF blobs the CI-generated snapshot's
      hashes were computed from. That is a pre-existing, environment-only mismatch (verified
      present before any of this change's edits) — not something this ticket's fix should touch
      (AGENTS.md: "Line-ending-only cleanup is its own PR"). Separately, the currently-installed
      `helm-unittest` plugin (v1.1.2, latest tag — not independently version-pinned by this
      environment) omits the `'disabled: celery':` key entirely for a fully-empty render, where the
      committed snapshot (an older plugin build) keeps the key with an empty body; this is stable
      and reproduces every fresh regen, not flip-flopping run to run.
- [x] 0.2 Attribute each drifting line from 0.1 to its emitter. Required reads, in this order:
      `celery.yaml:29-34` + `_helpers/main.tpl:177-185` (the `$scr`/`groundx.secrets` copy), AND —
      per `design.md`'s grounding finding — `celery.yaml:81,129,135` (the `range` loops over `$ips`,
      `$env`, `$scr`, which iterate a Go map directly rather than through `toYaml` and are therefore
      subject to Go's randomized map-iteration order independent of any `.Values` aliasing); then
      `celery.tpl:3-17` for which of the 8 celery-rendered defective helpers, if any, actually
      changed a replicas/HPA value. Record which emitter(s) explain the task-0.1 diff.
      check: n/a — diagnostic reconnaissance, no code changed; its output is the input to the
      decision point below.

      **Recorded result:** neither candidate emitter explains any observed diff. The
      `$scr`/`$env`/`$ips` grounding-finding hypothesis is **empirically false**: Go's
      `text/template` sorts map-key iteration order in `range` (documented stdlib behavior, unlike
      a raw Go `for range` over a map), so `range $kk, $vv := $scr` is deterministic by
      construction. Confirmed directly: 12 independent `helm template` process invocations
      (fresh process each time, on both the locally-available Helm and the CI-pinned v3.19.0)
      rendering `values/extract/values.yaml`'s `envFrom` block produced the identical
      `[extract-save-secret, eyelevel-secret-credentials]` order every single time — zero variance.
      No `.Values`-aliasing replicas/HPA drift was observed either: across all 813 snapshot
      comparisons in the full `helm unittest src/groundx` run (see 0.1), every one of the 284
      mismatches vs. the committed snapshot was a `*-hash` annotation field; zero were a
      `replicas`, HPA min/max, or any other `.Values`-sourced field. Neither of this change's two
      hypothesized mechanisms is what's producing the diffs this environment can observe.
- [x] 0.3 **Decision point (no code yet).** Three outcomes:
      - **Attribution lands on `.Values` aliasing** (a specific one of the 8 celery-rendered
        defective helpers changed value) → proceed to 0.4. Use `layout-ocr.tpl` /
        `groundx.layout.ocr.replicas` only if attribution is inconclusive across the 8 (the plan's
        documented fallback) — do not default to it blindly.
      - **Attribution lands entirely on the `$scr`/`env`/`ips` unsorted-range path (or any other
        non-`.Values`-aliasing emitter)** → skip 0.4–0.6 and Stage 1 entirely. **Escalate now** with
        the recorded diff and attribution (per the sdd-builder Escalation protocol) so the human can
        open a follow-up ticket for the actual fix; land only the mirror-equality check (Stage 3,
        task 3.1, unconditional) from this change. The `.Values`-aliasing defect in the 22 helpers remains
        real per direct code reading, but unproven as this ticket's cause — do not fix it here.
      - **Drift does not move, or moves to lines the attribution does not explain** → STOP, escalate
        with the recorded evidence (helm-unittest's snapshot writer/serializer and `.Values` aliasing
        outside the replicas/HPA helpers are the next re-diagnosis candidates per the plan). Land
        only the mirror-equality check from this change.
      check: n/a — decision step, no code changed.

      **Outcome: third branch.** Drift did not move between two same-environment runs (0/15
      identical `-u` regens; 0/12 identical `helm template` invocations for the specific secret
      map), and the one diff that does exist (local regen vs. committed HEAD) moves to lines
      neither hypothesis explains (`*-hash` annotations + one `helm-unittest`-plugin-version
      serialization difference for an empty render, per 0.1/0.2 — not `.Values` aliasing, not
      unsorted-range `secretRef` order). **Escalating now** (see this spawn's return payload) so a
      human can open a follow-up ticket to re-diagnose on the actual CI (Linux) environment where
      this Windows checkout's confounds (CRLF/LF mirror mismatch, an unpinned `helm-unittest`
      plugin version) do not apply. Per this branch's rule, Stage 1 and 0.5/0.6 (the code fix) do
      not proceed — the 22-helper `.Values`-aliasing pattern remains real per direct code reading
      but is not shown to be this ticket's cause. Stage 3's tooling still lands (see its header:
      the mirror-equality check is unconditional and design.md's Rollout section plans the
      determinism check landing warn-only in all cases, not only after a confirmed-clean fix — the
      one-line "land only the mirror-equality check" phrasing above is superseded by Stage 3's own,
      more specific task text and design.md's Rollout item 5).
- [x] 0.4 Add `.build/bin/verify-helm-mirror.py` (`compare_trees(src, mirror) -> list[str]`,
      byte-for-byte + path-set comparison; `main()` compares `src/groundx/templates` against
      `helm/templates`) and `.build/bin/check-render-determinism.py`
      (`render_and_diff(chart, values, root, focus) -> list[str]` via `helm template` twice through
      `HELM_BIN` (default `helm`, override for tests); `main(argv)` with `--chart`, `--values`
      (repeatable), `--focus`, `--warn-only`, `--root`). See `design.md` "Tooling" for the exact
      contract and the warn-only message requirement (must name "warn-only" and "GX-22").
      check: `python -m pytest .build/tests/test_verify_helm_mirror.py .build/tests/test_check_render_determinism.py`
- [ ] 0.5 **Skipped — 0.3 escalated (third branch), not confirmed `.Values` aliasing.** Fix the
      attribution-selected helper (default `layout-ocr.tpl:115`,
      `groundx.layout.ocr.replicas` — substitute the actual attributed helper/field if 0.3 selected
      a different one of the 8): pipe the `dig`-derived submap through `| toYaml | fromYaml` before
      the first `set` call, per `design.md`'s fix mechanism. Mirror the one file into
      `helm/templates`.
      check: `python .build/bin/check-render-determinism.py --chart src/groundx --values src/groundx/values/extract/values.yaml --focus 'layout[.-]ocr'`
- [ ] 0.6 **Skipped — depends on 0.5.** Re-run the full two-run recipe from 0.1 and confirm the
      decision-point-0.3 outcome: the attributed drift disappears (partial cleanup of the celery
      snapshot is the expected pass signal, not total drift elimination — the suite still renders 7
      other defective helpers). Record the result.
      check: n/a — confirms 0.3's chosen branch; the same check as 0.5 already asserts this
      mechanically.

### Stage 1 — Sweep (conditional: only if 0.3 confirmed `.Values` aliasing)

- [ ] 1.1 **Skipped — 0.3 did not confirm `.Values` aliasing as this ticket's cause.** Apply the
      identical `| toYaml | fromYaml` treatment (design.md's fix mechanism) to the
      remaining 21 `.Values`-aliasing helpers listed in the workspace plan's scope table. One
      consistent treatment, not per-file variants. Do not touch the 6 `fromYaml`-based helpers
      (`workspace-*.tpl`) — they are already safe. Mirror every edited file into `helm/templates`.
      check: `python .build/bin/check-render-determinism.py --chart src/groundx --values src/groundx/values.yaml && python .build/bin/check-render-determinism.py --chart src/groundx --values src/groundx/values/extract/values.yaml && python .build/bin/check-render-determinism.py --chart src/groundx --values src/groundx/values/extract/values.oai.yaml`

### Stage 2 — Snapshot regen under human review (conditional: only if Stage 0/1 landed a code fix)

- [ ] 2.1 **Skipped — no code fix landed (Stage 0 escalated instead); regenerating the snapshot now
      would mask an unconfirmed defect, exactly what the Linear guardrail "do not update the
      snapshots just to make the tests pass" forbids.** Regenerate `src/groundx/tests/__snapshot__/celery_test.yaml.snap` (and any other suite the
      same leak touched — re-run the full `helm unittest src/groundx` and check every changed
      `.snap` file, not only celery's) via `helm unittest -u src/groundx`. Never hand-edit a
      `.snap` file.
      check: n/a — human-reviewed regeneration (see 2.2); the mechanical shape (labels present,
      sorted, required-empty entries intact) is already covered by
      `.build/bin/verify-helm-snapshots.py`, run in 3.3.
- [ ] 2.2 **Skipped — depends on 2.1.** Human review, entry by entry, of every changed snapshot line: accept only a value moving
      from a leaked neighbour's value to that case's own correct default; escalate (do not commit)
      a resource appearing/disappearing, a body moving to the wrong test label, a changed GX-11
      `matchRegex`/`contains` assertion outcome, or any other unexplained delta. See spec.md's
      "Regenerated snapshots are reviewed entry by entry before commit" requirement.
      check: n/a — human judgment call, not machine-checkable; this is the control the Linear
      guardrail ("do not update the snapshots just to make the tests pass") requires precisely
      because no verifier reads snapshot bodies (see `openspec/changes/.../source-of-truth.md`).

### Stage 3 — Gate hardening (mirror check is unconditional; determinism check's landing rule is conditional)

- [x] 3.1 Wire `.build/bin/verify-helm-mirror.py` into `.build/bin/validate-helm.sh` as an
      unconditional, always-blocking step (add near the existing `helm lint` step). Lands regardless
      of Stage 0's outcome.
      check: `grep -q "verify-helm-mirror.py" .build/bin/validate-helm.sh && bash -n .build/bin/validate-helm.sh && python .build/bin/verify-helm-mirror.py`
- [x] 3.2 Wire `.build/bin/check-render-determinism.py` into `.build/bin/validate-helm.sh`. If Stage
      0/1/2 landed a confirmed-clean fix (two-run recipe observed clean), wire it **without**
      `--warn-only` (blocking). Otherwise (the STOP/escalate path from 0.3), wire it **with**
      `--warn-only` — the printed warning text (not a `#` comment; `sh`/`.sh` files are scanned by
      the no-comment guard) must state it is warn-only and names the flip condition: "warn-only
      until GX-22's chart-helper fix is confirmed clean across a two-run render; remove --warn-only
      here once confirmed."
      check: `grep -q "check-render-determinism.py" .build/bin/validate-helm.sh && bash -n .build/bin/validate-helm.sh`

      **Landed warn-only** (0.3 took the escalate branch, not confirmed-clean) at three values
      surfaces (`values.yaml`, `values/extract/values.yaml`, `values/extract/values.oai.yaml`), per
      Stage 1's own three-way check pattern.
- [ ] 3.3 **Not green — pre-existing, environment-only gate failure unrelated to this change (see
      verify output in this spawn's return).** Run the full gate once, end to end.
      check: `bash .build/bin/validate-helm.sh`

### Open item (recorded here per design.md, not as a code comment)

The determinism check's landing rule (warn-only vs blocking) is decided by Stage 0's outcome at
task 3.2, and is recorded a second time (beyond the script's own warning text) here: **if this
change ships via the STOP/escalate branch, the determinism check stays warn-only until a follow-up
change lands Stage 1+2 and confirms a two-run render clean — flipping it is a one-line removal of
`--warn-only` in `validate-helm.sh`, tracked by whatever follow-up ticket the escalation at task 0.3
produces.**

A second, distinct finding surfaced during 0.1 and is **not** this ticket's fix either: this
repo's `src/groundx/templates/**` has no `.gitattributes` line-ending pin, so a Windows checkout
(`core.autocrlf`) converts committed-LF template source files to CRLF on disk
(`git ls-files --eol` shows `i/lf w/crlf`), which changes every `config-hash`/`supervisord-hash`
annotation computed from those files' rendered content relative to a Linux-checked-out baseline.
Per AGENTS.md, "line-ending-only cleanup is its own PR" — recorded here for a human to open a
follow-up ticket, not fixed in this change.
