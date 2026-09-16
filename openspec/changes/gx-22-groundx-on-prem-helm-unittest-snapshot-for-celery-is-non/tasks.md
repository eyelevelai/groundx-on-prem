## Tasks

Implementation runs through the ambient Superpowers loop — this list is artifact-specific only.

See the workspace `openspec/changes/gx-22-groundx-on-prem-helm-unittest-snapshot-for-celery-is-non/`
proposal for the full 22-helper scope table and the six already-safe `fromYaml` exclusions; both are
restated in `design.md` only where needed to write a task.

### Stage 0 — Proof gate (do this first; nothing below is unconditional)

This stage alone is a complete, shippable slice: it either confirms the mechanism and unblocks
Stage 1, or it produces the escalation evidence and the change stops here with only the gate tooling
landed.

- [ ] 0.1 Reproduce the two-run drift on a clean base (helm off `PATH`; pin to v3.19.0 locally to
      match CI if available) and record the exact `git diff` of
      `src/groundx/tests/__snapshot__/celery_test.yaml.snap` across two successive
      `helm unittest src/groundx` runs. Do not assume the drifting entries match the ticket's list —
      record what actually changed.
      check: n/a — diagnostic reconnaissance, no code changed; its recorded output feeds task 0.2's
      attribution and is not itself a pass/fail condition.
- [ ] 0.2 Attribute each drifting line from 0.1 to its emitter. Required reads, in this order:
      `celery.yaml:29-34` + `_helpers/main.tpl:177-185` (the `$scr`/`groundx.secrets` copy), AND —
      per `design.md`'s grounding finding — `celery.yaml:81,129,135` (the `range` loops over `$ips`,
      `$env`, `$scr`, which iterate a Go map directly rather than through `toYaml` and are therefore
      subject to Go's randomized map-iteration order independent of any `.Values` aliasing); then
      `celery.tpl:3-17` for which of the 8 celery-rendered defective helpers, if any, actually
      changed a replicas/HPA value. Record which emitter(s) explain the task-0.1 diff.
      check: n/a — diagnostic reconnaissance, no code changed; its output is the input to the
      decision point below.
- [ ] 0.3 **Decision point (no code yet).** Three outcomes:
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
- [ ] 0.4 Add `.build/bin/verify-helm-mirror.py` (`compare_trees(src, mirror) -> list[str]`,
      byte-for-byte + path-set comparison; `main()` compares `src/groundx/templates` against
      `helm/templates`) and `.build/bin/check-render-determinism.py`
      (`render_and_diff(chart, values, root, focus) -> list[str]` via `helm template` twice through
      `HELM_BIN` (default `helm`, override for tests); `main(argv)` with `--chart`, `--values`
      (repeatable), `--focus`, `--warn-only`, `--root`). See `design.md` "Tooling" for the exact
      contract and the warn-only message requirement (must name "warn-only" and "GX-22").
      check: `python -m pytest .build/tests/test_verify_helm_mirror.py .build/tests/test_check_render_determinism.py`
- [ ] 0.5 Fix the attribution-selected helper (default `layout-ocr.tpl:115`,
      `groundx.layout.ocr.replicas` — substitute the actual attributed helper/field if 0.3 selected
      a different one of the 8): pipe the `dig`-derived submap through `| toYaml | fromYaml` before
      the first `set` call, per `design.md`'s fix mechanism. Mirror the one file into
      `helm/templates`.
      check: `python .build/bin/check-render-determinism.py --chart src/groundx --values src/groundx/values/extract/values.yaml --focus 'layout[.-]ocr'`
- [ ] 0.6 Re-run the full two-run recipe from 0.1 and confirm the decision-point-0.3 outcome: the
      attributed drift disappears (partial cleanup of the celery snapshot is the expected pass
      signal, not total drift elimination — the suite still renders 7 other defective helpers).
      Record the result.
      check: n/a — confirms 0.3's chosen branch; the same check as 0.5 already asserts this
      mechanically.

### Stage 1 — Sweep (conditional: only if 0.3 confirmed `.Values` aliasing)

- [ ] 1.1 Apply the identical `| toYaml | fromYaml` treatment (design.md's fix mechanism) to the
      remaining 21 `.Values`-aliasing helpers listed in the workspace plan's scope table. One
      consistent treatment, not per-file variants. Do not touch the 6 `fromYaml`-based helpers
      (`workspace-*.tpl`) — they are already safe. Mirror every edited file into `helm/templates`.
      check: `python .build/bin/check-render-determinism.py --chart src/groundx --values src/groundx/values.yaml && python .build/bin/check-render-determinism.py --chart src/groundx --values src/groundx/values/extract/values.yaml && python .build/bin/check-render-determinism.py --chart src/groundx --values src/groundx/values/extract/values.oai.yaml`

### Stage 2 — Snapshot regen under human review (conditional: only if Stage 0/1 landed a code fix)

- [ ] 2.1 Regenerate `src/groundx/tests/__snapshot__/celery_test.yaml.snap` (and any other suite the
      same leak touched — re-run the full `helm unittest src/groundx` and check every changed
      `.snap` file, not only celery's) via `helm unittest -u src/groundx`. Never hand-edit a
      `.snap` file.
      check: n/a — human-reviewed regeneration (see 2.2); the mechanical shape (labels present,
      sorted, required-empty entries intact) is already covered by
      `.build/bin/verify-helm-snapshots.py`, run in 3.3.
- [ ] 2.2 Human review, entry by entry, of every changed snapshot line: accept only a value moving
      from a leaked neighbour's value to that case's own correct default; escalate (do not commit)
      a resource appearing/disappearing, a body moving to the wrong test label, a changed GX-11
      `matchRegex`/`contains` assertion outcome, or any other unexplained delta. See spec.md's
      "Regenerated snapshots are reviewed entry by entry before commit" requirement.
      check: n/a — human judgment call, not machine-checkable; this is the control the Linear
      guardrail ("do not update the snapshots just to make the tests pass") requires precisely
      because no verifier reads snapshot bodies (see `openspec/changes/.../source-of-truth.md`).

### Stage 3 — Gate hardening (mirror check is unconditional; determinism check's landing rule is conditional)

- [ ] 3.1 Wire `.build/bin/verify-helm-mirror.py` into `.build/bin/validate-helm.sh` as an
      unconditional, always-blocking step (add near the existing `helm lint` step). Lands regardless
      of Stage 0's outcome.
      check: `grep -q "verify-helm-mirror.py" .build/bin/validate-helm.sh && bash -n .build/bin/validate-helm.sh && python .build/bin/verify-helm-mirror.py`
- [ ] 3.2 Wire `.build/bin/check-render-determinism.py` into `.build/bin/validate-helm.sh`. If Stage
      0/1/2 landed a confirmed-clean fix (two-run recipe observed clean), wire it **without**
      `--warn-only` (blocking). Otherwise (the STOP/escalate path from 0.3), wire it **with**
      `--warn-only` — the printed warning text (not a `#` comment; `sh`/`.sh` files are scanned by
      the no-comment guard) must state it is warn-only and names the flip condition: "warn-only
      until GX-22's chart-helper fix is confirmed clean across a two-run render; remove --warn-only
      here once confirmed."
      check: `grep -q "check-render-determinism.py" .build/bin/validate-helm.sh && bash -n .build/bin/validate-helm.sh`
- [ ] 3.3 Run the full gate once, end to end.
      check: `bash .build/bin/validate-helm.sh`

### Open item (recorded here per design.md, not as a code comment)

The determinism check's landing rule (warn-only vs blocking) is decided by Stage 0's outcome at
task 3.2, and is recorded a second time (beyond the script's own warning text) here: **if this
change ships via the STOP/escalate branch, the determinism check stays warn-only until a follow-up
change lands Stage 1+2 and confirms a two-run render clean — flipping it is a one-line removal of
`--warn-only` in `validate-helm.sh`, tracked by whatever follow-up ticket the escalation at task 0.3
produces.**
