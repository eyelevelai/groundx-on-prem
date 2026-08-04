# Ranker Inference Windowed Busy HPA Design

## Goal

Scale ranker inference from a stable per-pod busy-time signal instead of a
point-in-time worker sample or queue backlog.

## HPA Contract

The rendered ranker inference HPA uses one external metric by default:

```text
ranker-inference:inference
```

`ranker-inference:inference` is the pod-specific busy-time axis.

`ranker-inference:throughput` is opt-in. If
`ranker.inference.replicas.throughput` is greater than `0`, the chart still
renders the throughput HPA metric. The base chart default is `0`, because this
service should scale from actual inference busy time instead of request
throughput.

## Metrics Config

The chart renders ranker inference in `metrics.inference`:

```yaml
inference:
  - name: ranker-inference
    busyWindowSeconds: 60
```

The ranker inference entry is removed from `metrics.task`.

cashbot-go computes this metric from the existing metrics Redis session:

- ai-server marks a worker busy when ranker inference starts handling a task.
- ai-server marks the worker available in `finally` and writes elapsed
  milliseconds into second-sized Redis buckets.
- cashbot-go sums completed busy buckets inside the configured window.
- cashbot-go also counts currently active workers from their busy start keys,
  capped to the same window.
- The external metric value is busy milliseconds divided by
  `online workers * busyWindowSeconds`.

For windowed inference metrics, cashbot-go does not use the old instantaneous
availability sample.

## Redis Contract

Ranker busy samples are written to the same Redis configured by `metricsBroker`.
That is the existing metrics cache in the chart.

If `ranker.cache.addr` is set, ranker search/Celery brokers use that ranker
cache, but the busy HPA metric still uses `metrics.session`. The chart does not
render `metrics.sessions.ranker-inference` for the busy metric.

## Sensitivity

The default window is `60` seconds. The default HPA target is `0.5`, so a
single one-second request on one worker reports about `0.0167`, not `1.0`.
Sustained saturation across the window is required before the pod-specific
metric reaches the scale target.

## Ranker API Batch Size

`ranker.api.batchSize` renders into ranker config as `rankerBatchSize`. The
default is `3`, based on live canary testing with production-like search
payloads. Successful responses kept the same score hash during the canary.

## Source And Mirror

`src/groundx` remains the chart source of truth. The same changed templates are
mirrored into `helm/` so the published chart path does not silently drift.

## Live Validation

Because ranker inference pods can require GPU node launch plus model readiness,
rendered correctness is not enough. After approval, validate under a controlled
ramp while watching:

- `ranker-inference:inference`
- Redis `ranker-inference:*:busy_start_ms`
- Redis `ranker-inference:busy:*:ms`
- HPA events
- Pending pods
- GPU node readiness
- model readiness
- ranker API latency
- Lambda duration and errors

If `ranker.cache.addr` is overridden, confirm ranker search/Celery uses the
ranker cache while busy samples still land in the metrics cache.

## Non-Goals

- No ranker API HPA or capacity metric change.
- No task backlog metric change for other Celery workers.
- No node, GPU, Cluster Autoscaler, secret, search, ranking, or data change.
