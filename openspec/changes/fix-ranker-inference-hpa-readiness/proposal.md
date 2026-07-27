# Use Ranker Inference Queue Back-Pressure HPA

## Why

Ranker inference is a Celery worker pool, but the chart rendered its
pod-specific HPA signal as `ranker-inference:inference`. That older signal uses
point-in-time model worker state and can miss pressure between HPA samples.

Other Celery workers already scale from queue backlog through the existing
cashbot-go `task` metric. The smallest chart fix is to wire ranker inference to
that same queue back-pressure path.

## What Changes

- Render the ranker inference pod-specific HPA metric as
  `ranker-inference:task`.
- Keep `ranker-inference:throughput` as the pipeline throughput axis.
- Move ranker inference metrics config from `metrics.inference` to
  `metrics.task`.
- Render the ranker task session key from the ranker inference service name.
- Set the ranker task target to `inference_queue`.
- Default the ranker task threshold to the existing task backlog default, `10`.
- Mirror source chart changes into `helm/`.

## Out Of Scope

- No ranker API HPA change.
- No new cashbot-go metric type.
- No ai-server image or health contract change.
- No search, ranking, OpenSearch, node group, Cluster Autoscaler, secret, or
  stateful resource change.
- No deployment without separate approval.

## Rollout

1. Deploy the chart change after approval.
2. Confirm the deployed ranker inference HPA uses `ranker-inference:task` and
   `ranker-inference:throughput`.
3. Confirm rendered `config.yaml` lists ranker inference under `metrics.task`
   with `session: ranker-inference`, `target: inference_queue`, and
   `threshold: 10`.
4. At idle, confirm `ranker-inference:task` remains near zero.
5. During a controlled ramp, compare `LLEN {celery}inference_queue` with the
   Kubernetes external metric.
6. Watch HPA events, Pending pods, GPU node readiness, model readiness,
   ranker-inference CPU/GPU, ranker API latency, and Lambda duration/errors.
7. Tune `ranker.inference.replicas.threshold` only from live ramp data.

## Rollback

Roll back the chart to the previous ranker inference HPA metric if
`ranker-inference:task` does not match live broker state. No data rollback is
required.
