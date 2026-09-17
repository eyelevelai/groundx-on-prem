## Decisions

**Invariant (gate — mirror equality, already landed, unaffected by this amendment).** Every file
under `src/groundx/templates` must have a byte-identical counterpart at the same relative path
under `helm/templates`, and vice versa, before either surface is trusted as a deploy artifact. A
rename, edit, or add on one side that is not mirrored on the other is a broken build, not accepted
drift.

**Invariant (gate — repeat-render determinism, already landed, unaffected by this amendment).** Two
renders of the chart from the same `.Values` input should be byte-identical. This check renders
through the `helm` binary directly, so it can only ever observe a chart-template-level defect
(e.g. an un-copied `.Values` submap, an unsorted raw-map `range`) — it structurally cannot observe
a defect in the `helm-unittest` plugin's own snapshot cache/serializer, which is this ticket's
actual root cause. It therefore stays warn-only **permanently in this change**, with no flip
condition: flipping it to blocking would assert a coverage guarantee ("this check would have caught
GX-22") that is false. A future change that finds a genuine chart-template nondeterminism defect
proven by this check may propose flipping it then, on its own evidence, via its own ticket.

**Invariant (gate — pinned `helm-unittest` plugin version).** The gate must fail whenever the
`helm-unittest` release actually resolved and installed at runtime differs from the version named
at the single pinned source of truth — not merely whether an install command in a workflow file or
doc happens to mention a version string. A pin that is asserted only in prose (a doc, a workflow
step someone can edit without re-reading) is not a pin; the assertion must read the version the
installed plugin binary itself reports.

**Invariant (gate — snapshot-rewrite-on-run).** No file under `src/groundx/tests/__snapshot__` may
be modified as a side effect of running `helm unittest` itself. The check must compare snapshot
content captured immediately before the run to content captured immediately after — never against
git's working-tree dirty status — so a snapshot a human legitimately edited or regenerated *before*
this run started is never mistaken for a rewrite `helm unittest` itself performed during this run.

## Grounding finding — corrected root cause (supersedes the withdrawn `.Values`-aliasing /
unsorted-range hypotheses)

Reading `install-binary.sh`, the `helm-unittest` plugin's own snapshot cache source, and this repo's
checkout state (rather than the chart templates) surfaces the actual emitter of the ticket's
reported symptom:

- `helm plugin install https://github.com/helm-unittest/helm-unittest.git` (every install site in
  this repo: `.github/workflows/helm-tests.yml:25`, `docs/agents/repo-guide.md:24`,
  `ARCHITECTURE_NOTES.md:75`) carries no `--version`, so the plugin's own `install-binary.sh:86-94`
  resolves and downloads whatever release `plugin.yaml` on the plugin's `main` branch currently
  names — today `v1.1.2` — never a build of the plugin's clone HEAD (`git describe`'s stdout is
  redirected there, so resolution always falls through to the `plugin.yaml` version string).
  Confirmed against the actually-installed binary via `go version -m`.
- That release's snapshot cache (`pkg/unittest/snapshot/cache.go:159-181`,
  `StoreToFileIfNeeded`) rewrites the **entire** `.snap` file whenever any snapshot entry was
  inserted or vanished, retains cached bodies for unchanged entries (`:111`), and counts only
  *updated* entries as failures (`:199-204` `FailedCount`, `:206-219` `VanishedCount`) — so a
  vanished empty-render label (`disabled: celery`) is silently dropped from the file while the run
  still reports **PASS**. This is the ticket's reported symptom verbatim: "rewrites the snapshot
  ... yet the run still reports PASS," and "the `disabled: celery` key sometimes dropped."
- Separately, this repo has no `.gitattributes` line-ending pin, so a Windows checkout
  (`core.autocrlf`) renders `src/groundx/templates/resources/*.yaml` with CRLF against the LF blobs
  the committed snapshot's `*-hash` annotations were computed from — harmless churn confined to
  hash-annotation fields, unrelated to the plugin-cache defect, found investigating this ticket and
  worth closing at the same time (`git ls-files --eol` confirms `i/lf w/crlf` on this checkout).

Both of the plan's earlier hypotheses — the `.Values`-aliasing replica/HPA helper leak, and an
unsorted Go map-`range` order in `celery.yaml`'s `$scr`/`$env`/`$ips` loops — are empirically
falsified (Stage 0, tasks.md): 0 of 284 observed snapshot mismatches touched a replicas/HPA or
`secretRef` value; Go's `text/template` sorts map-key `range` order by documented contract, and 12
independent renders confirmed zero variance. Neither is this ticket's cause. The `.Values`-aliasing
pattern remains a real code smell by direct reading of the 22 helpers, but it is proven irrelevant
to this ticket's reported drift — tracked as its own follow-up (not yet filed; see tasks.md).

## Fix mechanism

- **`.gitattributes`** (new, repo root) pins chart source (`src/groundx/templates/**`,
  `helm/templates/**`, and related YAML/JSON) to `eol=lf`. Checkout-policy only — no index-content
  delta, since the committed blobs are already LF; this only forces every future checkout's
  *working-tree* bytes (this Windows checkout included) to match what CI already renders from.
- **Plugin-version pin at a single source of truth.** A single one-line file,
  `.build/HELM_UNITTEST_VERSION`, is the pin. Every install site reads it rather than hard-coding
  the version a second time: `.github/workflows/helm-tests.yml`'s install step becomes
  `helm plugin install https://github.com/helm-unittest/helm-unittest.git --version "$(cat
  .build/HELM_UNITTEST_VERSION)"`; `docs/agents/repo-guide.md` and `ARCHITECTURE_NOTES.md` are
  updated to show the same `--version "$(cat .build/HELM_UNITTEST_VERSION)"` form (prose, kept in
  sync by the human editing them — no regen script exists for docs prose, same as every other doc
  reference in this repo); `scripts/githooks/groundx-on-prem/install.sh` and its `NOTES.md` in the
  meta-repo are a human-pass follow-up (see tasks.md's unboxed cross-repo note) since they live
  outside this service repo.
- **Two new gate assertions in `.build/bin/validate-helm.sh`:**
  1. **Plugin-version match** — fails if the plugin actually installed does not resolve to the
     version named in `.build/HELM_UNITTEST_VERSION`. Runs before `helm unittest` (no point running
     tests against the wrong tool).
  2. **Snapshot-rewrite-on-run** — fails if any file under `src/groundx/tests/__snapshot__` changed
     content between a hash captured just before the gate's `helm unittest src/groundx` invocation
     and a hash captured immediately after it. Placed **immediately after that invocation**
     (`validate-helm.sh:59` today), not at the end of the script: `verify-helm-snapshots.py`
     (`validate-helm.sh:94`, under `set -euo pipefail`) already exits the script first on exactly
     this failure class — a vanished empty-render label — so an end-of-script placement would never
     run on the failure this assertion exists to catch.
- **Chosen fork (human decision, plan gate round 6): option (a).** Freeze
  `.build/HELM_UNITTEST_VERSION` on the newest older `helm-unittest` release that still emits every
  required empty-render label (the 24 labels across 9 snapshot files `verify-helm-snapshots.py`'s
  `REQUIRED_EMPTY_LABELS` already asserts), found via an empirical backward tag search (tasks.md
  Stage B). This requires **no snapshot regeneration** — Stage D is a no-op under this fork — and
  keeps `verify-helm-snapshots.py`'s existing guarantees fully intact, unlike option (b) (accept the
  current release, loosen the verifier's empty-label checks), which was considered and rejected: it
  would weaken an active guardrail to accommodate a tool defect instead of pinning around the
  defect. Option (a) is also reversible and cheap to determine empirically before committing to it.

## Tooling: guard-script conventions (Guard change class)

Both new assertions are guards (AGENTS.md "Guard change class"), so each lives in its own
sourceable, directly-testable file, following this repo's existing convention (`.build/bin/verify-*.py`
+ `.build/tests/test_*.py` — e.g. `verify-helm-snapshots.py`, `verify-helm-mirror.py`,
`check-render-determinism.py`) rather than embedding the classification logic inline in
`validate-helm.sh` or inventing a parallel bash test harness. This also matches the repo's
`openspec/config.yaml` `context:` note captured during this ticket: "Guard/verifier scripts live at
`.build/bin/<name>.py` with unit tests at `.build/tests/test_<name>.py` ... prefer it over embedding
check logic inline in the shell script."

- **`.build/bin/verify-helm-unittest-plugin-version.py`** — `pinned_version(pin_file: Path) -> str`
  reads and strips `.build/HELM_UNITTEST_VERSION`; `installed_version(plugins_dir: Path) -> str |
  None` resolves the plugin's install directory (via `helm env HELM_PLUGINS`, falling back to the
  conventional `~/.local/share/helm/plugins`) and reads the `version:` field out of
  `helm-unittest/plugin.yaml`. `main()` fails closed — missing pin file, missing plugin, or
  unreadable `plugin.yaml` is a failure, never a silent pass — and fails loudly on a version
  mismatch, printing both values. Fixtures (same commit, per Guard change class (c)): a fake plugin
  dir whose `plugin.yaml` reports a different version than the pin (must REJECT), and one that
  matches (must NOT block).
- **`.build/bin/verify-helm-snapshot-stability.py`** — two subcommands so the same script can
  straddle a specific point in `validate-helm.sh`'s sequential execution: `capture <hashfile>` walks
  `src/groundx/tests/__snapshot__` and writes a per-file content hash to `<hashfile>`; `verify
  <hashfile>` recomputes the same hashes and fails, naming every changed file, if they differ from
  what was captured. `validate-helm.sh` calls `capture` once near the top of the script (before
  `helm lint`, so it reflects the tree's state before anything in the gate has touched it — matching
  spec.md's must-not-block case: a tree that already had committed-vs-working snapshot differences
  *before this run started* still passes, because the check compares against the hash captured at
  that starting point, never against git's dirty/clean status) and `verify` immediately after
  `helm unittest src/groundx`. Fixtures: a snapshot file mutated between `capture` and `verify` (must
  REJECT, naming the changed file) and an unchanged run, including one where the captured baseline
  already differs from git `HEAD` (must NOT block).
- A standalone script (not inline shell hashing) is chosen for both because the classification logic
  — "does this plugin.yaml version match," "did this file's content change since capture" — needs to
  be exercised directly by a fixture per Guard change class (c), the same reason the two already-landed
  checkers are Python rather than bash.

## Rollout

All three deploy targets render from the same chart version, the same `helm/` mirror, and the same
toolchain pin (see proposal.md's blast-radius note) — nothing here is environment-specific, so there
is no canary/stage ordering to sequence. Landing order inside this change: (1) `.gitattributes`
(Stage A, zero-risk checkout policy); (2) the plugin-version pin + its gate assertion (Stage A); (3)
the empirical backward-tag search and the chosen-fork pin value (Stage B); (4) the
snapshot-rewrite-on-run assertion, placed immediately after the `helm unittest` invocation (Stage
C); (5) a full end-to-end gate run once (1)–(4) land. No step in this landing order can leave a
broken-and-blocking gate behind on revert: both new assertions are additive, and reverting the
`.gitattributes`/pin file only returns the repo to its pre-change (already-known-broken) state, never
a worse one.

## Open items carried into tasks.md

Per AGENTS.md's no-comment rule, neither open item below is recorded as a `#`/`//` comment in any
script — both are recorded here and restated in tasks.md:

- The withdrawn 22-helper `.Values`-aliasing sweep (`layout-ocr.tpl` and 21 siblings) is a real code
  smell by direct reading, proven irrelevant to this ticket's observed diffs. Needs its own Linear
  ticket, not yet filed.
- Flipping `check-render-determinism.py` to blocking is out of scope for this change (see the
  Invariant above — this check cannot observe the actual defect class GX-22 fixes). Would need its
  own ticket and its own evidence of a genuine chart-template nondeterminism defect if pursued later.
