## Why

Layout capacity readers scan Redis to find each pod's process records: ai-server's layout `/health` once per worker per check, and cashbot-go's metrics service three times per layout metric read. Every record name is already predictable from the pod name, the number of Celery workers in the pod, and the number of processes per worker, and the chart already knows those numbers. Publishing them lets both readers build the exact names and fetch them directly (GX-102, GX-146).

## What Changes

- Layout `config.py` gets `threads=` next to `workers=`, so layout `/health` can build its own record names.
- Every inference Deployment (layout, ranker, summary) carries the pod annotations `groundx.ai/celery-workers` and `groundx.ai/celery-threads`, rendered from the same settings that start Celery, with autoscaling on or off.
- The layout-inference entry of `metrics.inference` in `config.yaml` sets `exactKeys: true`, which tells cashbot-go to read layout capacity by exact name.

## Capabilities

- `inference-pod-counts` (new): the worker and process counts the chart publishes for capacity readers.

## Impact

Rendered layout config, inference pod annotations and the cashbot-go metrics config. Changing a pod annotation or `config.py` rolls the affected pods, as any config change does. Older ai-server images ignore `threads`, and an older cashbot-go ignores `exactKeys` and the annotations. No values or schema change.
