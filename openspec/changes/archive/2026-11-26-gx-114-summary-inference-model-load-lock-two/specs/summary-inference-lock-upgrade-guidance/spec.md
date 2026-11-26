## ADDED Requirements

### Requirement: The upgrade guide states the old/new pod overlap risk and its remedy

`docs/upgrades.md` SHALL state, next to the existing summary `updateStrategy: Recreate` and scale-to-zero guidance, that during the upgrade introducing the summary-inference model-load lock (`initializing.flock`), an old pod that restarts while old and new pods overlap can load its model alongside a new pod. It SHALL name `summary.inference.updateStrategy: Recreate` and scaling summary-inference to zero before upgrading as the two ways to remove that overlap. It SHALL NOT add a new procedure section or a new command sequence; it SHALL point at the scale-to-zero steps already in "Inference model downloads".

#### Scenario: The overlap risk and both remedies are stated (polarity: finalize success)

- **GIVEN** `docs/upgrades.md` on this branch
- **WHEN** an operator reads the summary upgrade guidance
- **THEN** it says an old pod restarting during the old/new overlap can load alongside a new pod, and names `updateStrategy: Recreate` and scaling summary-inference to zero as the remedies

#### Scenario: No new procedure section is added (polarity: skip unrelated repair path)

- **GIVEN** the same file after the change
- **WHEN** its headings are compared with those before the change
- **THEN** no heading was added; the note sits inside an existing section, and the opposite outcome (a new top-level procedure heading for this note) does not appear

### Requirement: The upgrade guide states the file-lock storage requirement, its symptom and its remedy

`docs/upgrades.md` SHALL state that summary-inference now needs file-lock support on its model volume and that this was tested on EFS only. It SHALL state this in the "Persistent storage" section, since every summary worker takes the lock on every model load at any node count. It SHALL state that on a fresh install the first symptom is the `download-model` init container's file-lock error, and that on an upgrade the worker logs `model load failed; exiting worker` with a traceback from `fcntl.flock` on `initializing.flock` and restarts, so summary does not come up; the traceback, not the log line alone, identifies the lock failure. It SHALL name the remedy: a storage class with lock support (with a new `summary.inference.pvc.name`, since an existing claim cannot change its storage class), or rolling the chart back. It SHALL NOT claim that other storage classes were tested or that the failure is detected before the pod starts.

#### Scenario: The requirement, symptom and remedy are stated (polarity: finalize failure)

- **GIVEN** an operator whose model volume is on storage that rejects file locks
- **WHEN** they read the note
- **THEN** it says the worker logs `model load failed; exiting worker` with an `fcntl.flock` traceback and restarts, summary does not come up, and the remedy is a storage class with lock support or a chart rollback; a reader is not told summary will start without locks

#### Scenario: The test coverage claim is bounded (polarity: reject before state)

- **GIVEN** the same note
- **WHEN** a reader looks for which storage was verified
- **THEN** only EFS is named as tested, and no other storage class is stated as supported

### Requirement: The change touches documentation only

The change SHALL modify `docs/upgrades.md` and the change's own OpenSpec folder, and no chart template, values file, schema, snapshot or `helm/` mirror file.

#### Scenario: No rendered or chart file changes (backward compatibility)

- **GIVEN** an existing 0.3.0 install and chart sources
- **WHEN** this change is applied
- **THEN** `git diff --name-only origin/0.3.0...HEAD` lists no path under `src/`, `helm/` or `helm-releases/`, so rendered manifests and values behave exactly as before
