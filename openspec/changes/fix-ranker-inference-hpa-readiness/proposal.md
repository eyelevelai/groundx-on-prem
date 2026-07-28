# Use Windowed Ranker Inference Busy HPA

## Why

Ranker inference is a Celery worker pool running long GPU tasks. Queue backlog
was a poor HPA signal because one queued request could make the metric look
fully saturated even while a single replica was still healthy. The older
`ranker-inference:inference` signal was also too point-in-time because it
sampled whether a worker happened to be busy when the metrics server checked.

The fix is to make `ranker-inference:inference` mean average busy time over a
short window. ai-server records busy starts/finishes into the existing metrics
Redis, cashbot-go reads those samples through the existing metrics session, and
the chart wires ranker inference to that metric.

## What Changes

- Render the ranker inference pod-specific HPA metric as
  `ranker-inference:inference`.
- Keep `ranker-inference:throughput` as the pipeline throughput axis.
- Render ranker inference under `metrics.inference` with
  `busyWindowSeconds`, defaulting to `60`.
- Pass the same `metricsBusyWindowSeconds` value to ranker ai-server config.
- Keep ranker busy samples on the existing `metrics.session` Redis path. If
  `ranker.cache.addr` is overridden, search/Celery traffic uses that ranker
  cache, but the HPA busy metric still uses the metrics cache.
- Remove ranker inference from `metrics.task`; no ranker-specific
  `metrics.sessions` block is rendered for this metric.
- Default the HPA target to `0.9`.
- Mirror source chart changes into `helm/`.
- Add the cashbot-go reader and ai-server writer changes required by this
  chart contract.

## Out Of Scope

- No ranker API HPA change.
- No search, ranking, OpenSearch, node group, Cluster Autoscaler, secret, or
  stateful resource change.
- No deployment without separate approval.

## Rollout

1. Deploy the chart change after approval.
2. Confirm the deployed ranker inference HPA uses `ranker-inference:inference`
   and
   `ranker-inference:throughput`.
3. Confirm rendered `config.yaml` lists ranker inference under
   `metrics.inference` with `busyWindowSeconds: 60`.
4. Confirm rendered ranker config includes `metricsBusyWindowSeconds=60` and
   points `metricsBroker` at the metrics cache.
5. At idle, confirm `ranker-inference:inference` remains near zero.
6. During a controlled ramp, compare active/in-flight ranker requests with the
   Kubernetes external metric over the configured window.
6. Watch HPA events, Pending pods, GPU node readiness, model readiness,
   ranker-inference CPU/GPU, ranker API latency, and Lambda duration/errors.
7. Tune `ranker.inference.busyWindowSeconds` or
   `ranker.inference.replicas.target` only from live ramp data.

## Rollback

Disable `ranker.inference.busyWindowSeconds` and roll back the chart/app images
if the windowed metric does not match live ranker activity. No data rollback is
required.
