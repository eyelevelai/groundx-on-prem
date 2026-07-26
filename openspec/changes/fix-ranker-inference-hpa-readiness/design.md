# Fix Ranker Autoscaling Readiness Design

## Goals

- Make ranker readiness behave like layout and summary readiness.
- Keep ranker worker-capacity records alive during idle periods.
- Start adding ranker capacity before the current pod is saturated.
- Keep one always-on ranker replica after traffic subsides.
- Scale ranker API from current request-slot use instead of delayed latency or
  a separate throughput signal.

## Non-Goals

- No GPU node or Cluster Autoscaler changes.
- No search behavior changes.
- No secret changes.
- Deployment requires separate approval.

## Current Failure

`ai-server` records each ranker worker as available or busy and exposes
`/health`. The chart still marks ranker inference with a Celery process setting,
which selects process-based probes in the shared inference template. Kubernetes
therefore never polls `/health`.

Idle worker records expire from Redis after five minutes. Once they expire, the
external HPA metric no longer has an accurate ranker-capacity baseline.

The hosted inference HPA also uses a target of `0.8`, which did not scale during
the observed 100 requests/minute strain.

Ranker API now publishes process-unique request-slot capacity, and cashbot-go
uses it for the `capacity` metric type. The chart still renders the older
`ranker-api:throughput` metric and defaults the API target to `1`, so the HPA
does not yet match the new metric contract.

## Design

### AI-server health contract

Ranker workers report available status at startup and restore it after every
request, including failures. The ranker health server reports:

- `/alive`: the health process is running;
- `/health`: all configured ranker workers are registered.

Kubernetes polling of `/health` refreshes worker records while the service is
idle.

### Helm probe parity

Add a ranker inference container-port helper with default port `8080`. Include
that port in ranker inference settings and remove the Celery marker that selects
process probes.

The shared inference template will then render the same HTTP readiness and
liveness probes used by layout and summary inference.

### Hosted HPA settings

Use:

```yaml
ranker:
  inference:
    replicas:
      desired: 1
      min: 1
      max: 4
      target: 0.7
      threshold: 60000
      throughput: 60000
      upCooldown: 60
      cooldown: 450
```

The target controls worker-occupancy scaling. The throughput values remain the
initial sizing floor. `upCooldown` stays at one minute to avoid reacting to
one-off fanout spikes. The 450-second cooldown produces a 900-second scale-down
stabilization window.

### Ranker API capacity HPA

Render ranker API with one external metric:

```text
ranker-api:capacity target 0.7
```

The metric is current request-slot utilization from online API workers. Do not
also render `ranker-api:throughput`; that older signal could scale independently
and would make the HPA behavior differ from the cashbot-go capacity contract.
The generated app `config.yaml` must define the ranker API under
`metrics.capacity`.
This does not change ranker inference, which keeps its existing throughput
fallback.

### Metric ownership

This chart continues to point the HPA at `ranker-inference:inference`. The
rolling busy calculation is owned by ai-server and cashbot-go in the
`add-ranker-rolling-busy-hpa-metric` change. This Helm change only keeps ranker
worker records fresh, preserves one minimum replica, and sets the HPA target and
cooldowns.

## Source Evidence

- `ai-server/ranker/tasks/inference.py`
- `ai-server/ranker_monitor.py`
- `ai-server/ranker_health.py`
- `ai-server/constants.py`
- `cashbot-go/openspec/changes/add-ranker-rolling-busy-hpa-metric/design.md`
- `groundx-on-prem/src/groundx/templates/_helpers/app/ranker-inference.tpl`
- `groundx-on-prem/src/groundx/templates/_helpers/app/ranker-api.tpl`
- `groundx-on-prem/src/groundx/templates/app/inference.yaml`
- `groundx-on-prem/src/groundx/templates/resources/hpa.yaml`
- `cashbot-go/pkg/operator/metrics.go`

## Rollout

Production deployment was approved on 2026-07-25:

1. Build and publish the ranker image.
2. Deploy the hosted ranker values with one minimum ranker replica.
3. Deploy the matching cashbot-go PR 1535 metrics server that reads
   `ranker-inference:inference` and `ranker-api:capacity`.
4. Confirm `/alive` and `/health` pass and the external metric retains its idle
   capacity baseline for more than five minutes.
5. Confirm sampled `ranker-inference:*` worker keys map to current EKS ranker
   pods.
6. Monitor ranker Redis `inference_queue` depth directly during the ramp; do
   not rely on the existing cashbot-go task metric for this signal.
7. Apply a controlled load and confirm HPA requests a second replica before the
   first is saturated.
8. Confirm scale-down returns to one replica.
9. Promote to production in a separate operation.

Because each new ranker pod requires a GPU node, node startup remains a separate
capacity risk. This change improves the HPA signal but does not change node
provisioning.

## Rollback

Deploy the previous image and chart, then restore the prior HPA target and
cooldown. No data rollback is required.

## Validation

- focused Helm test fails before the probe fix and passes after it;
- `python -m unittest ranker.tasks.test_inference_status`;
- `python -m py_compile` for changed ranker Python modules;
- `helm lint src/groundx -f values.ranker-only-eks.yaml`;
- `helm lint helm -f values.ranker-only-eks.yaml`;
- `helm unittest src/groundx`;
- hosted values render review for ranker probes and HPA;
- source/mirror comparison;
- `OPENSPEC_TELEMETRY=0 npx --yes @fission-ai/openspec@1.3.1 validate --all --strict --json`;
- `git diff --check`.
