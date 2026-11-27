# inference-pod-counts Specification

## Purpose
The Celery worker and process counts the chart publishes so capacity readers can build exact Redis record names instead of scanning.
## Requirements
### Requirement: Inference pods publish their Celery worker and process counts

Every inference Deployment rendered by `templates/app/inference.yaml` whose settings define `workers` and `threads` SHALL carry the pod template annotations `groundx.ai/celery-workers` and `groundx.ai/celery-threads` with those values, whether or not autoscaling is enabled. The values SHALL come from the same settings the service's supervisord config uses to start its Celery workers.

#### Scenario: Overridden layout counts reach the pod with autoscaling off (polarity: finalize success)

- **GIVEN** `cluster.hpa: false`, `layout.inference.workers: 2`, `layout.inference.threads: 4`, and summary inference enabled with `summary.inference.workers: 3`
- **WHEN** the inference Deployments render
- **THEN** the layout-inference pod template has `groundx.ai/celery-workers: "2"` and `groundx.ai/celery-threads: "4"`
- **AND** ranker-inference has its defaults `"14"` and `"1"`, and summary-inference has `groundx.ai/celery-workers: "3"`

### Requirement: Layout publishes its process count to the health check and cashbot-go

The layout `config.py` SHALL render `threads` from `groundx.layout.inference.threads` next to `workers`. The layout-inference entry of `metrics.inference` in `config.yaml` SHALL set `exactKeys: true`; no other inference entry SHALL set it.

#### Scenario: Layout config and metric entry carry the counts (polarity: finalize success)

- **GIVEN** `layout.inference.workers: 2` and `layout.inference.threads: 4`
- **WHEN** the layout `config.py` and `config.yaml` render
- **THEN** `config.py` has `workers=2,` followed by `threads=4,`
- **AND** the layout-inference metric entry has `exactKeys: true` and the ranker-inference entry does not
