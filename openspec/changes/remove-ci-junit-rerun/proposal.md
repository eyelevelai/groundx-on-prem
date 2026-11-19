## Why

The Helm workflow reruns the complete test suite to produce a JUnit artifact.
No configured repository check consumes that artifact. In run 44433765720,
the reporting run took 3 minutes 55 seconds of the 10-minute PR workflow.

## What Changes

Run the production gate without `--junit` and remove the report upload step.
Keep the optional local reporting flag and all existing regression checks.

## Impact

Only GitHub Actions reporting changes. No chart, cluster, credentials or
stateful resources change in dev, staging or production. Reverting the
workflow edit restores the downloadable XML artifact and duplicate run.
