# helm-chart-render-determinism Specification

## Purpose
Define how `.build/bin/validate-helm.sh` guards the chart's render determinism: `helm/` and
`src/groundx/templates` stay byte-identical mirrors, a `helm unittest` run must not rewrite the
committed snapshots it runs against, regenerated snapshots are reviewed entry by entry before
commit, and the installed `helm-unittest` plugin (both its declared version and its actual binary
bytes) matches the repo's single pinned version.

## Requirements
### Requirement: The build gate enforces `helm/` ↔ `src/groundx/templates` mirror equality

`.build/bin/validate-helm.sh` SHALL fail whenever any file under `src/groundx/templates` and its counterpart at the same relative path under `helm/templates` are not byte-identical, or exist on only one side — unconditionally, from the moment this check lands, independent of GX-22's root cause or its STOP/proceed outcome.

#### Scenario: An unmirrored template edit is rejected (catches)

- **GIVEN** a file under `src/groundx/templates` was edited but the matching `helm/templates` file
  was not updated to match
- **WHEN** the mirror-equality check runs
- **THEN** it reports the file and fails
- **Polarity:** reject before state — the drifted mirror is never accepted as a valid deploy
  artifact.

#### Scenario: An identical mirror passes (must-not-block)

- **GIVEN** `helm/templates` is byte-identical to `src/groundx/templates`, file for file
- **WHEN** the mirror-equality check runs
- **THEN** it passes
- **Polarity:** finalize success.

### Requirement: Regenerated snapshots are reviewed entry by entry before commit

A regenerated `src/groundx/tests/__snapshot__/*.snap` file SHALL never be committed from a blind `helm unittest -u`, and each changed entry SHALL be reviewed and classified before commit.

#### Scenario: A leak-to-own-default correction is accepted (must-not-block)

- **GIVEN** a regenerated snapshot entry's only change is a value moving from a leaked neighbour's
  value to that test case's own correct default
- **WHEN** the entry is reviewed
- **THEN** it is accepted and committed
- **Polarity:** finalize success.

#### Scenario: An unexplained snapshot change is escalated, not committed (catches)

- **GIVEN** a regenerated snapshot entry shows a Kubernetes resource appearing or disappearing, a
  body moving under a different test label, a GX-11 `matchRegex`/`contains` assertion behaving
  differently, or any delta not explainable as a leak-to-own-default correction
- **WHEN** the entry is reviewed
- **THEN** it is not committed; the change is escalated with the diff instead
- **Polarity:** reject before state — an unexplained snapshot change never becomes the new
  accepted golden.

### Requirement: The build gate fails on a `helm unittest`-driven snapshot rewrite

`.build/bin/validate-helm.sh` SHALL fail if any file under `src/groundx/tests/__snapshot__` was
rewritten during its own run — content captured immediately before its `helm unittest` invocation
and compared against content captured immediately after it. The assertion runs immediately after
each `helm unittest` invocation, before any later step in the script; running it only at the end of
the script would never catch this failure class, because `verify-helm-snapshots.py`'s own
label-presence check already exits the script first, under `set -euo pipefail`, on exactly the
vanished-empty-render-label rewrite this assertion targets.

#### Scenario: A snapshot rewritten mid-run is caught (catches)

- **GIVEN** a hash of every file under `src/groundx/tests/__snapshot__` was captured before
  `helm unittest src/groundx` ran
- **WHEN** the `helm unittest src/groundx` invocation performs a structural insert or vanish of a
  snapshot test case (this assertion's real target: `helm-unittest`'s snapshot cache
  (`pkg/unittest/snapshot/cache.go`) writes the `.snap` file whenever `insertedCount > 0` or
  `VanishedCount() > 0`, and `FailedCount()` counts only `updatedCount` — both apply identically
  whether or not `-u` is passed, so this write-and-silent-PASS path is reachable in the plain
  invocation this gate runs, not `-u`-exclusive. GX-22's investigation reproduced the drop-and-PASS
  symptom end to end under `-u`; no plain-mode run in 15+ trials happened to produce a structural
  insert/vanish, so this assertion defends a path confirmed reachable but not yet directly observed
  in plain mode, not a hypothetical one)
- **THEN** the assertion immediately following that invocation recomputes the hashes, finds a
  mismatch, names the changed file, and fails the script — before `verify-helm-snapshots.py` or any
  later step runs
- **Polarity:** finalize failure — the rewrite is reported as a defect at the point it happened,
  never allowed to reach a later check that might exit the script for an unrelated reason first.

#### Scenario: A clean run, and a run starting from an already-modified tree, both pass
  (must-not-block)

- **GIVEN** either (a) `src/groundx/tests/__snapshot__` is unchanged by `helm unittest src/groundx`,
  or (b) the working tree already had committed snapshot changes staged or edited before this run
  started, and `helm unittest src/groundx` does not change them further
- **WHEN** the assertion runs immediately after that invocation
- **THEN** it passes in both cases, because it compares captured-before-this-run content against
  captured-after-this-run content, never against git's working-tree dirty/clean status
- **Polarity:** finalize success — a snapshot's pre-existing state, however it got there, is never
  itself the failure condition; only a change caused by this run's own `helm unittest` invocation is.

### Requirement: The build gate enforces the pinned `helm-unittest` plugin version

`.build/bin/validate-helm.sh` SHALL fail whenever the installed `helm-unittest` plugin does not
match `.build/HELM_UNITTEST_VERSION`, the single pinned source of truth, via a two-part check: (1)
the installed plugin's own `plugin.yaml` declares the same version as the pin, and (2) the
installed `untt-<os>-<arch>[.exe]` binary's SHA-256 matches the committed reference hash for the
resolved platform in `.build/HELM_UNITTEST_BINARY_SHA256` — because the plugin's own install
script skips re-downloading whenever a same-named binary file already exists, so a stale binary
can sit behind a correct version string, and the `untt` binary itself has no version flag to read
directly. A missing pin file, a missing plugin install, an unreadable `plugin.yaml`, a missing or
unreadable installed binary, or a missing/malformed/mismatched reference hash entry SHALL also
fail the gate, never pass silently.

#### Scenario: A mismatched installed plugin version is rejected (catches)

- **GIVEN** `.build/HELM_UNITTEST_VERSION` names one version and the installed `helm-unittest`
  plugin's own `plugin.yaml` reports a different version
- **WHEN** the plugin-version guard runs
- **THEN** it reports both versions and fails
- **Polarity:** reject before state — `helm unittest` never runs against the wrong tool.

#### Scenario: A matching installed plugin version passes (must-not-block)

- **GIVEN** the installed `helm-unittest` plugin's `plugin.yaml` reports the same version named in
  `.build/HELM_UNITTEST_VERSION`, and its installed `untt-<os>-<arch>[.exe]` binary's SHA-256
  matches the committed reference hash for the resolved platform
- **WHEN** the plugin-version guard runs
- **THEN** it passes
- **Polarity:** finalize success.

#### Scenario: A correct declared version with stale binary bytes is rejected (catches)

- **GIVEN** the installed `helm-unittest` plugin's `plugin.yaml` reports the same version named in
  `.build/HELM_UNITTEST_VERSION`, but the installed `untt-<os>-<arch>[.exe]` binary's SHA-256 does
  not match the committed reference hash for the resolved platform in
  `.build/HELM_UNITTEST_BINARY_SHA256`
- **WHEN** the plugin-version guard runs
- **THEN** it reports both hashes and fails, without ever reaching `helm unittest`
- **Polarity:** reject before state — a correct-looking version string never stands in for the
  actual installed binary bytes.

