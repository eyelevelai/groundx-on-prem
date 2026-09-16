## ADDED Requirements

### Requirement: Replica/HPA helper rendering does not leak state across renders

The chart's `.Values`-aliasing replica/HPA helpers (the 22 helpers listed in the accepted cross-service plan's scope table) SHALL render every replicas/HPA field identically across repeated `helm template` invocations from the same input, because the submap each helper reads from `.Values` is copied before any `set` call, never mutated by reference.

#### Scenario: Repeated render of the celery suite is stable (must-not-block)

- **GIVEN** the chart's `.Values`-aliasing replica/HPA helpers copy their submap before mutating it
- **WHEN** `helm template` renders the celery workloads twice from identical values
- **THEN** every replicas/HPA field in the two renders is byte-identical
- **Polarity:** finalize success — the render is accepted as stable, not flagged as drift.

#### Scenario: A reintroduced in-place mutation is caught (catches)

- **GIVEN** a helper's replicas/HPA submap is obtained by `dig` and mutated with `set` without a
  copy (the pre-fix shape)
- **WHEN** the chart is rendered twice from identical values
- **THEN** the repeat-render determinism check reports the diverging field as a diff
- **Polarity:** finalize failure — the drift is reported as a defect, never silently re-goldened
  into the snapshot as if it were expected output.

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

### Requirement: The repeat-render determinism check lands warn-only, then flips to blocking

`.build/bin/validate-helm.sh` SHALL run a repeat-render determinism check that renders the chart twice from the same values and reports any diff, SHALL warn rather than fail the script until a two-run recipe is observed clean after Stage 1 and Stage 2 land, SHALL state in that warning that it is warn-only and name the condition under which it becomes blocking, and SHALL block on any diff once observed clean.

#### Scenario: Warn-only mode does not block an unresolved baseline (must-not-block)

- **GIVEN** GX-22's fix has not yet been confirmed clean across the sweep (the STOP path, or before
  Stage 1+2 land)
- **WHEN** the repeat-render determinism check finds a diff
- **THEN** it prints the diff and a message stating it is warn-only and the condition that flips it
  to blocking, and the script continues (exit 0 from this step)
- **Polarity:** skip unrelated repair path — an unresolved baseline is not routed into a hard
  failure before the fix it depends on has landed.

#### Scenario: Blocking mode rejects drift once flipped (catches)

- **GIVEN** the determinism check has been switched to blocking (Stage 1+2 landed, a two-run
  recipe was observed clean)
- **WHEN** a later change reintroduces a render diff
- **THEN** the check fails the script
- **Polarity:** finalize failure.

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
