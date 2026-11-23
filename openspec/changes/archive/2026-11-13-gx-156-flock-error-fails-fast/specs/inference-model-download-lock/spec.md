## MODIFIED Requirements

### Requirement: A missing flock fails at once
The script SHALL first exit 0 without downloading when `complete.<model>` already exists, so a missing `flock` never fails a pod whose model volume is complete. When the marker is absent it SHALL check that `flock` exists before any wait and exit non-zero naming `flock` when it is missing. A `flock -n` failure that prints nothing is contention and SHALL be retried every 3 seconds until the 60-minute limit. A `flock -n` failure that prints an error SHALL end the container at once with a non-zero exit and a message carrying that error, without the waiting message, a download request or a marker. Polarity: `reject before state`.

#### Scenario: flock applet missing
- **GIVEN** an image where `flock` is not on the `PATH`
- **WHEN** the container starts on a volume with no `complete.<model>`
- **THEN** it exits non-zero at once with a message naming flock, makes no download request and writes no marker

#### Scenario: flock applet missing but the model is already complete
- **GIVEN** an image where `flock` is not on the `PATH` and a volume holding `complete.<model>`
- **WHEN** the container starts
- **THEN** it exits 0 without any download request and without failing on the missing flock

#### Scenario: flock reports an error
- **GIVEN** a `flock` that prints an error and exits 1
- **WHEN** the container starts on an empty volume
- **THEN** it exits non-zero at once with a message carrying that error, never prints "Download in progress by another pod", makes no download request and writes no marker

#### Scenario: Silent flock failure is contention
- **GIVEN** a `flock` that exits 1 and prints nothing
- **WHEN** the container starts on an empty volume
- **THEN** it keeps running, reports that it is waiting, and makes no download request
