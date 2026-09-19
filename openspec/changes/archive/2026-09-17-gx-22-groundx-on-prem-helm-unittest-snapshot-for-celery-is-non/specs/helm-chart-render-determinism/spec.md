## ADDED Requirements

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

### Requirement: The repeat-render determinism check lands warn-only, with no flip condition in this change

`.build/bin/validate-helm.sh` SHALL run a repeat-render determinism check that renders the chart twice from the same values and reports any diff, and SHALL warn rather than fail the script on any diff it finds, stating in that warning that it is warn-only. This change introduces no condition under which it becomes blocking: the check renders through the `helm` binary directly and structurally cannot observe a defect in the `helm-unittest` plugin's own snapshot cache/serializer, which is this ticket's actual root cause — so an observed-clean render proves nothing about GX-22's fix and must not be used to flip this check.

#### Scenario: Warn-only mode never blocks on a render diff (must-not-block)

- **GIVEN** the repeat-render determinism check is wired into `.build/bin/validate-helm.sh`
- **WHEN** it finds a diff between two renders of the chart from the same values
- **THEN** it prints the diff and a message stating it is warn-only, and the script continues (exit
  0 from this step)
- **Polarity:** skip unrelated repair path — a render diff this check finds is not routed into a
  hard failure, because this check cannot attribute the diff to GX-22's actual defect class.

#### Scenario: A clean two-run render also does not block (must-not-block)

- **GIVEN** the repeat-render determinism check finds no diff between two renders
- **WHEN** the check runs
- **THEN** it passes, as it always has, with no change in behavior triggered by this being clean
- **Polarity:** finalize success — a clean result is accepted as the ordinary case, not treated as
  the trigger for a mode change this change does not implement.

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
  snapshot test case (this assertion's defense-in-depth target; GX-22's investigation confirmed the
  `helm-unittest` plugin's empty-render-label-drop mechanism is triggered only by `-u`, never by
  the plain invocation this gate runs, so this assertion guards against a hypothetical future
  structural rewrite, not a currently-observed defect in the plain-mode gate)
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

`.build/bin/validate-helm.sh` SHALL fail whenever the `helm-unittest` plugin version actually
installed and resolved at runtime does not match the version named in
`.build/HELM_UNITTEST_VERSION`, the single pinned source of truth — reading the version the
installed plugin binary itself reports, never merely an install command in a workflow file or doc.
A missing pin file, a missing plugin install, or an unreadable `plugin.yaml` SHALL also fail the
gate, never pass silently.

#### Scenario: A mismatched installed plugin version is rejected (catches)

- **GIVEN** `.build/HELM_UNITTEST_VERSION` names one version and the installed `helm-unittest`
  plugin's own `plugin.yaml` reports a different version
- **WHEN** the plugin-version guard runs
- **THEN** it reports both versions and fails
- **Polarity:** reject before state — `helm unittest` never runs against the wrong tool.

#### Scenario: A matching installed plugin version passes (must-not-block)

- **GIVEN** the installed `helm-unittest` plugin's `plugin.yaml` reports the same version named in
  `.build/HELM_UNITTEST_VERSION`
- **WHEN** the plugin-version guard runs
- **THEN** it passes
- **Polarity:** finalize success.
