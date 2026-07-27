# Ranker Inference Queue Back-Pressure HPA Design

## Goal

Reuse the existing Celery task backlog autoscaling implementation for ranker
inference with the smallest chart change.

## HPA Contract

The rendered ranker inference HPA uses two external metrics:

```text
ranker-inference:throughput
ranker-inference:task
```

`ranker-inference:throughput` stays as the existing pipeline throughput axis.
`ranker-inference:task` becomes the pod-specific back-pressure axis.

## Metrics Config

The chart renders ranker inference in `metrics.task`:

```yaml
task:
  - name: ranker-inference
    session: ranker-inference
    target: inference_queue
    threshold: 10
```

The ranker inference entry is removed from `metrics.inference`.

cashbot-go already implements `task` metrics by reading
`{celery}<target queue>` and dividing the backlog by `threshold`. The chart
supplies the ranker inference task config and marks it with the rendered service
name, `session: ranker-inference`, so cashbot-go can use a named Redis session
when one is configured.

When `ranker.cache.addr` is set, the chart also renders:

```yaml
sessions:
  ranker-inference:
    addr: <ranker cache addr>:<ranker cache port>
    notCluster: <derived from ranker.cache.isCluster>
    ssl: <ranker cache ssl>
```

When ranker uses the global cache, `sessions.ranker-inference` is omitted and
cashbot-go falls back to the existing process Redis path.

## Threshold

The default ranker inference task threshold is `10`, matching the existing task
backlog default documented in the GroundX Studio Harness autoscaling reference.

A threshold of `1` is intentionally avoided because one queued ranker task would
report full utilization and can make GPU HPA behavior too sensitive.

## Source And Mirror

`src/groundx` remains the chart source of truth. The same changed templates are
mirrored into `helm/` so the published chart path does not silently drift.

## Live Validation

Because ranker inference pods can require GPU node launch plus model readiness,
rendered correctness is not enough. After approval, validate under a controlled
ramp while watching:

- `ranker-inference:task`
- `LLEN {celery}inference_queue`
- HPA events
- Pending pods
- GPU node readiness
- model readiness
- ranker API latency
- Lambda duration and errors

If `ranker.cache.addr` is overridden, confirm the metrics server reads the Redis
instance that owns `{celery}inference_queue`.

## Non-Goals

- No ranker API HPA or capacity metric change.
- No new cashbot-go task metric algorithm.
- No ai-server image, worker-health, or ranker-specific metric change.
- No node, GPU, Cluster Autoscaler, secret, search, ranking, or data change.
