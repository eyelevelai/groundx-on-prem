## ADDED Requirements

### Requirement: A dead download holder never blocks later pods
The `download-model` init container SHALL serialise the first model download with an OS-released advisory lock taken on a write-opened file descriptor of `download.lock` in the model volume (`exec 9>>"$lock"; flock -n 9`). Because the OS releases a dead holder's lock, a later pod SHALL acquire the lock and download the model without manual cleanup. The script SHALL NOT write or honour the old presence-only `downloading` file; the lock holder SHALL remove a leftover `downloading` file and partial `<base>.tar.*` files before downloading. Polarity: `accept and enqueue`.

#### Scenario: Stale downloading file with no live holder
- **GIVEN** a model volume holding a leftover `downloading` file and a partial part file, and no running download
- **WHEN** a new `download-model` container starts
- **THEN** it acquires the lock, removes `downloading` and the partial part file, downloads every part, writes `complete.<model>` and exits 0
- **AND** it does not wait on the leftover `downloading` file

#### Scenario: No lock and no marker
- **GIVEN** an empty model volume
- **WHEN** a `download-model` container starts
- **THEN** it downloads every part exactly once and writes `complete.<model>`

### Requirement: A live holder is waited on, never stolen from or duplicated
A pod that cannot acquire the lock because another process holds it (silent `flock -n` exit code 1) SHALL print a waiting message, retry every 3 seconds, and, once it acquires the lock, re-check `complete.<model>`: when the marker exists it SHALL exit 0 without downloading. Two pods starting together on an empty volume SHALL download each part once in total. Polarity: `skip unrelated repair path`.

#### Scenario: Waiter behind a live holder
- **GIVEN** one container holding the lock part-way through a download
- **WHEN** a second container starts on the same volume
- **THEN** the second container keeps running and reports that it is waiting, and makes no download request
- **AND** once the holder finishes, the second container exits 0 with the model already complete and without downloading again

#### Scenario: Two concurrent starts
- **GIVEN** an empty model volume
- **WHEN** two `download-model` containers start at the same time
- **THEN** both exit 0, the marker exists, and each part was requested exactly once in total

### Requirement: The lock wait is bounded and fails visibly
The script SHALL stop waiting after 60 minutes (a script constant, `wait_limit=3600`), print a message naming the timeout, and exit non-zero. Polarity: `finalize failure`.

#### Scenario: Waiter outlasts the limit
- **GIVEN** a lock that stays held beyond the limit
- **WHEN** the waiter's elapsed time reaches 3600 seconds
- **THEN** the container exits non-zero with a timeout message and writes no marker

### Requirement: An unusable flock fails at once
The script SHALL first exit 0 without downloading when `complete.<model>` already exists, so a missing `flock` never fails a pod whose model volume is complete. When the marker is absent it SHALL check that `flock` exists before any wait and exit non-zero naming `flock` when it is missing. It SHALL retry only a silent exit code 1 as contention; any `flock -n` failure that prints an error or exits with another code SHALL exit non-zero immediately with that output. It SHALL NOT wait out the 60-minute limit on such a failure and SHALL NOT start a download. Polarity: `reject before state`.

#### Scenario: flock applet missing
- **GIVEN** an image where `flock` is not on the `PATH`
- **WHEN** the container starts on a volume with no `complete.<model>`
- **THEN** it exits non-zero at once with a message naming flock, makes no download request and writes no marker

#### Scenario: flock applet missing but the model is already complete
- **GIVEN** an image where `flock` is not on the `PATH` and a volume holding `complete.<model>`
- **WHEN** the container starts
- **THEN** it exits 0 without any download request and without failing on the missing flock

#### Scenario: flock rejects the lock
- **GIVEN** a `flock` that prints `Bad file descriptor` and exits 1
- **WHEN** the container starts on an empty volume
- **THEN** it exits non-zero at once with a message naming flock, makes no download request and writes no marker
- **AND** it is not treated as contention

#### Scenario: Silent exit code 1 is contention
- **GIVEN** a `flock` that exits 1 with no output
- **WHEN** the container starts
- **THEN** it keeps running and reports that it is waiting, and does not exit

### Requirement: A failed download is never marked complete
The script SHALL exit non-zero, and SHALL NOT write `complete.<model>`, when any `wget`, `tar` or `xargs` step fails. `complete.<model>` SHALL be written only after every part downloaded and extracted and the archives were removed, while the lock is still held. Polarity: `finalize failure`.

#### Scenario: Every download fails
- **GIVEN** a volume with no marker and a `wget` that always fails
- **WHEN** the container runs
- **THEN** it exits non-zero after three attempts per part and `complete.<model>` does not exist

#### Scenario: A part is not a valid archive
- **GIVEN** a `wget` that succeeds but writes a file `tar` cannot extract
- **WHEN** the container runs
- **THEN** it exits non-zero and `complete.<model>` does not exist

### Requirement: The lock is taken by file descriptor on a write-opened file
The script SHALL lock with `exec 9>>"$lock"` followed by `flock -n 9` and SHALL NOT use the `flock <path> <command>` form, which busybox opens read-only and which never acquires on EFS. Polarity: `reject before state`.

#### Scenario: Path-form flock is rejected by the guard
- **GIVEN** a rendered script that calls `flock "$lock" <command>` and has no write-opened fd
- **WHEN** the lock guard checks it
- **THEN** the guard fails

#### Scenario: Fd form passes the guard
- **GIVEN** the rendered script opens `exec 9>>"$lock"` and calls `flock -n 9`
- **WHEN** the lock guard checks it
- **THEN** the static check passes and does not block the legitimate form

### Requirement: Both chart surfaces render the same script
`src/groundx/templates/app/inference.yaml` and `helm/templates/app/inference.yaml` SHALL render the same `download-model` command for every inference service (layout, ranker, summary), and the hand-patched golden snapshots for `inference_test.yaml` and `ranker_test.yaml` SHALL match the rendered script. Polarity: `reject before state`.

#### Scenario: Mirror drift is caught
- **GIVEN** `helm/` differs from `src/groundx` in the `download-model` command of any inference service
- **WHEN** the lock guard renders both charts
- **THEN** the guard fails naming the service

#### Scenario: Identical surfaces pass
- **GIVEN** both charts render byte-identical scripts
- **WHEN** the guard compares them
- **THEN** the mirror check passes

### Requirement: The guard runs in the chart gate
`.build/bin/validate-helm.sh` SHALL run `src/groundx/tests/files/verify-download-model-lock.sh` in a step announced as `==> Verifying download-model flock lock and failed-download handling (see GX-125)`. The guard SHALL run the rendered script in the chart's busybox image through Docker with a stubbed `wget`, SHALL fail closed naming the missing tool when `helm`, `yq` or `docker` is unavailable, and SHALL prove the `wget` stub intercepts the script before relying on it. Polarity: `reject before state`.

#### Scenario: Docker unavailable
- **GIVEN** `docker` is not on the `PATH` or its daemon is unreachable
- **WHEN** the guard runs
- **THEN** it exits non-zero naming docker, and does not pass vacuously

#### Scenario: Guard fails on the pre-change template
- **GIVEN** the template with the presence-only `downloading` lock
- **WHEN** the guard runs
- **THEN** the stale-lock case times out, the failed-download cases report a zero exit with a written marker, and the guard exits non-zero

### Requirement: The README documents the upgrade, rollback and failure behaviour
The root `README.md` SHALL carry a `#### Upgrading Inference Services and the Model Download Lock` subsection before `### Persistent Storage` covering: scale the service to 0 and wait until no inference pod remains (Terminating pods included) before upgrading while a first download is in progress, and likewise before rolling back to an older chart while a new-chart pod is mid first download; a failed download or a waiter beyond 60 minutes ends in `Init:Error` / `CrashLoopBackOff`, so air-gapped installs seed the model volume before scaling up; a missing or rejected `flock` fails the init container at once and is fixed with a busybox image that provides flock or storage that supports file locks, with no value to bypass the lock; and cross-node locking is verified on EFS only. It SHALL NOT name a chart version. Polarity: `accept and enqueue`.

#### Scenario: Note present and complete
- **GIVEN** the README after the change
- **WHEN** the subsection is extracted
- **THEN** it is non-empty and contains each of the topics above

#### Scenario: Backward compatibility during rollout
- **GIVEN** an old-chart pod and a new-chart pod running against the same volume during a first download
- **WHEN** an operator follows the README note
- **THEN** the service is scaled to 0 and every inference pod, Terminating ones included, is gone first so the two lock mechanisms never overlap, and a volume already holding `complete.<model>` is skipped by both versions
