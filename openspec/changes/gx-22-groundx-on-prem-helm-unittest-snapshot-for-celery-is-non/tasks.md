## Tasks

Implementation runs through the ambient Superpowers loop — this list is artifact-specific only.

See the workspace `openspec/changes/gx-22-groundx-on-prem-helm-unittest-snapshot-for-celery-is-non/`
proposal for the full cross-service verification notes. Cross-repo coordination note (not a
per-service checkbox): `scripts/githooks/groundx-on-prem/install.sh` and its `NOTES.md`
(meta-repo) need the same `.build/HELM_UNITTEST_VERSION` pin applied by a human pass once Stage A
lands here — see the workspace `openspec/changes/.../tasks.md` for that coordination item; it is
not a task of this service repo.

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

      **Amendment note (post-escalation re-plan).** This third-branch outcome — and the two decision
      points above it — is the accurate history that led to re-opening the plan. It stands as
      written; nothing in it is re-litigated. The corrected root cause (an unpinned `helm-unittest`
      plugin release whose snapshot cache silently drops a vanished empty-render label) was found
      afterward, during design authorship of the re-opened plan — see `design.md`'s "Grounding
      finding." Stages A–D below are that amended plan's tasks.

- [x] 0.4 Add `.build/bin/verify-helm-mirror.py` (`compare_trees(src, mirror) -> list[str]`,
      byte-for-byte + path-set comparison; `main()` compares `src/groundx/templates` against
      `helm/templates`) and `.build/bin/check-render-determinism.py`
      (`render_and_diff(chart, values, root, focus) -> list[str]` via `helm template` twice through
      `HELM_BIN` (default `helm`, override for tests); `main(argv)` with `--chart`, `--values`
      (repeatable), `--focus`, `--warn-only`, `--root`). See `design.md` "Tooling" for the exact
      contract and the warn-only message requirement (must name "warn-only" and "GX-22").
      check: `python -m pytest .build/tests/test_verify_helm_mirror.py .build/tests/test_check_render_determinism.py`
- [ ] 0.5 **WITHDRAWN** — 0.3 escalated (third branch); the corrected re-plan's root cause is an
      unpinned `helm-unittest` plugin release, not `.Values` aliasing. The 22-helper deep-copy fix
      this task described is a real but separate hardening item — needs its own Linear ticket, not
      yet filed (see design.md "Open items carried into tasks.md"). Kept here, not deleted, so a
      future reader sees it was considered and rejected as this ticket's fix, not overlooked.
      check: n/a — withdrawn, no code written for this task.
- [ ] 0.6 **WITHDRAWN** — depended on 0.5, which is withdrawn for the same reason. See design.md
      "Open items carried into tasks.md" for the follow-up-ticket pointer.
      check: n/a — withdrawn, no code written for this task.

### Stage 1 — Sweep (WITHDRAWN — the confirmed root cause is not `.Values` aliasing)

- [ ] 1.1 **WITHDRAWN.** The 22-helper `| toYaml | fromYaml` sweep this task described remains a
      real code smell by direct reading (`layout-ocr.tpl` and 21 siblings), proven irrelevant to
      every diff this ticket's Stage 0 observed. Needs its own Linear ticket, not yet filed — see
      design.md "Open items carried into tasks.md." Kept here as a record of a considered-and-rejected
      approach, not deleted.
      check: n/a — withdrawn, no code written for this task.

### Stage 2 — Snapshot regen under human review (WITHDRAWN — not needed under the chosen fork)

- [ ] 2.1 **WITHDRAWN** — superseded by design.md's "Fix mechanism": the human's chosen fork
      (option a) freezes the `helm-unittest` plugin on an older release that already emits every
      required empty-render label, so no snapshot regeneration is needed. Regenerating the snapshot
      under the original (withdrawn) hypothesis would have masked an unconfirmed defect — exactly
      what the Linear guardrail "do not update the snapshots just to make the tests pass" forbids.
      check: n/a — withdrawn, no code written for this task.
- [ ] 2.2 **WITHDRAWN** — depended on 2.1, which is withdrawn for the same reason.
      check: n/a — withdrawn, no code written for this task.

### Stage A — Toolchain pinning (`.gitattributes` + plugin-version pin + assertion)

- [ ] A.1 Add `.gitattributes` (repo root) pinning `src/groundx/templates/**`, `helm/templates/**`,
      and related chart YAML/JSON to `eol=lf`. Confirm zero index-content delta (the committed blobs
      are already LF; this only changes future working-tree checkout behavior).
      check: `git check-attr eol -- src/groundx/templates/resources/layout-config-py.yaml helm/templates/resources/layout-config-py.yaml | grep -c 'eol: lf' | grep -q '^2$' && git diff --stat --exit-code`
- [ ] A.2 Add `.build/HELM_UNITTEST_VERSION` (one line, the pinned plugin release tag) as the single
      source of truth. Update `.github/workflows/helm-tests.yml`'s install step to
      `helm plugin install https://github.com/helm-unittest/helm-unittest.git --version "$(cat
      .build/HELM_UNITTEST_VERSION)"`, and `docs/agents/repo-guide.md` + `ARCHITECTURE_NOTES.md` to
      show the same pinned-install form.
      check: `test -s .build/HELM_UNITTEST_VERSION && grep -q 'HELM_UNITTEST_VERSION' .github/workflows/helm-tests.yml docs/agents/repo-guide.md ARCHITECTURE_NOTES.md`
- [ ] A.3 Add `.build/bin/verify-helm-unittest-plugin-version.py` (`pinned_version(pin_file) -> str`,
      `installed_version(plugins_dir) -> str | None` reading the installed plugin's own
      `plugin.yaml`; `main()` fails closed on a missing pin file, missing plugin, unreadable
      `plugin.yaml`, or a version mismatch — see design.md "Tooling") with fixtures (a fake
      plugin.yaml reporting a different version; one matching the pin), and wire it into
      `.build/bin/validate-helm.sh` before the `helm unittest` invocation.
      check: `python -m pytest .build/tests/test_verify_helm_unittest_plugin_version.py`

### Stage B — Execute the chosen fork (empirical backward tag search)

- [ ] B.1 Backward tag search from `helm-unittest`'s newest release: for each candidate tag, install
      it, run `helm unittest -u src/groundx`, and check every one of `verify-helm-snapshots.py`'s
      `REQUIRED_EMPTY_LABELS` (24 labels, 9 files) survives — present, and still emitted as an
      explicit empty entry, not silently dropped. Select the **newest** tag that passes. Record the
      chosen tag and the evidence for each tag tried in this file.
      check: n/a — empirical investigation feeding A.2's pin choice; mirrors Stage 0.1/0.2's
      diagnostic-reconnaissance pattern, not itself a pass/fail condition.
- [ ] B.2 Set `.build/HELM_UNITTEST_VERSION` to the tag selected in B.1 (if different from a
      placeholder used in A.2). With `.gitattributes` from A.1 already applied, confirm a byte-clean
      two-run recipe: `helm unittest -u src/groundx` produces a `.snap` tree with zero diff against
      committed `HEAD`, and a second plain `helm unittest src/groundx` run leaves it unchanged.
      check: `helm unittest -u src/groundx && git diff --stat --exit-code -- src/groundx/tests/__snapshot__ && helm unittest src/groundx && git diff --stat --exit-code -- src/groundx/tests/__snapshot__`

### Stage C — Snapshot-rewrite-on-run assertion

- [ ] C.1 Add `.build/bin/verify-helm-snapshot-stability.py` — `capture <hashfile>` hashes every
      file under `src/groundx/tests/__snapshot__` and writes the result to `<hashfile>`; `verify
      <hashfile>` recomputes and fails, naming every changed file, if the hashes differ. See
      design.md "Tooling" for the full contract. Fixtures: a snapshot mutated between `capture` and
      `verify` (must REJECT); an unchanged run, and a run whose captured baseline already differed
      from git `HEAD` before capture (both must NOT block).
      check: `python -m pytest .build/tests/test_verify_helm_snapshot_stability.py`
- [ ] C.2 Wire it into `.build/bin/validate-helm.sh`: `capture` runs near the top of the script
      (before `helm lint`); `verify` runs immediately after the `helm unittest src/groundx`
      invocation (today `validate-helm.sh:59`) — strictly before `verify-helm-snapshots.py`
      (today `validate-helm.sh:94`), which already exits the script first under `set -euo pipefail`
      on exactly this failure class.
      check: `bash -n .build/bin/validate-helm.sh && awk '/verify-helm-snapshot-stability.py verify/{v=NR} /verify-helm-snapshots\.py$/{s=NR} END{exit !(v && s && v<s)}' .build/bin/validate-helm.sh`
- [ ] C.3 Re-run the full gate end to end now that Stage A/B/C have landed. This supersedes the
      earlier 3.3 attempt below, which failed only on the pre-existing CRLF/unpinned-plugin
      confounds Stage A/B remove.
      check: `bash .build/bin/validate-helm.sh`

### Stage D — Snapshot regeneration

Not applicable under the chosen fork (option a). Freezing on an older plugin release that already
emits every required empty-render label requires no snapshot regeneration, so this change has no
human-reviewed regen step (unlike the withdrawn plan's Stage 2 above).

### Stage 3 — Gate hardening (already landed; mirror check unconditional, determinism check
warn-only permanently — unaffected by this amendment)

- [x] 3.1 Wire `.build/bin/verify-helm-mirror.py` into `.build/bin/validate-helm.sh` as an
      unconditional, always-blocking step (add near the existing `helm lint` step). Lands regardless
      of Stage 0's outcome.
      check: `grep -q "verify-helm-mirror.py" .build/bin/validate-helm.sh && bash -n .build/bin/validate-helm.sh && python .build/bin/verify-helm-mirror.py`
- [x] 3.2 Wire `.build/bin/check-render-determinism.py` into `.build/bin/validate-helm.sh`, wired
      with `--warn-only` — permanently in this change, per design.md's Invariant (this check
      structurally cannot observe GX-22's actual defect class, so no Stage 0/1/2 outcome flips it).
      The printed warning text (not a `#` comment; `.sh` files are scanned by the no-comment guard)
      states it is warn-only.
      check: `grep -q "check-render-determinism.py" .build/bin/validate-helm.sh && bash -n .build/bin/validate-helm.sh`

      **Landed warn-only** (0.3 took the escalate branch, not confirmed-clean) at three values
      surfaces (`values.yaml`, `values/extract/values.yaml`, `values/extract/values.oai.yaml`), per
      Stage 1's own three-way check pattern.
- [x] 3.3 **Not green — pre-existing, environment-only gate failure unrelated to this change (see
      verify output in this spawn's return).** Run the full gate once, end to end.
      check: `bash .build/bin/validate-helm.sh`

      **Note:** Stage C.3 re-attempts this after Stage A/B/C land, since Stage A/B remove the exact
      confounds (CRLF mirror mismatch, unpinned plugin version) that made this run fail.

### Open items (recorded here per design.md, not as a code comment)

The 22-helper `.Values`-aliasing sweep (Stage 1, withdrawn) remains a real code smell per direct
code reading, proven irrelevant to this ticket's observed diffs — needs its own Linear ticket, not
yet filed.

`check-render-determinism.py` stays warn-only permanently in this change (design.md's Invariant) —
it structurally cannot observe GX-22's actual defect class. Flipping it to blocking would need its
own ticket and its own evidence of a genuine chart-template nondeterminism defect, if one is ever
found.

This repo's `src/groundx/templates/**` line-ending pin (`.gitattributes`, Stage A.1) closes the
CRLF/LF confound recorded during Stage 0.1 — per AGENTS.md, "line-ending-only cleanup is its own
PR," but here it is bundled with the toolchain pin because both were found investigating the same
symptom and neither touches chart template content; see proposal.md's amendment note.
