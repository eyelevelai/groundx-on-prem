# Fix Ranker Inference HPA Readiness Design

## Goals

- Make ranker readiness behave like layout and summary readiness.
- Keep ranker worker-capacity records alive during idle periods.
- Start adding ranker capacity before the current pod is saturated.
- Keep one always-on ranker replica after traffic subsides.

## Non-Goals

- No GPU node or Cluster Autoscaler changes.
- No search behavior changes.
- No secret changes.
- No deployment.

## Current Failure

`ai-server` records each ranker worker as available or busy and exposes
`/health`. The chart still marks ranker inference with a Celery process setting,
which selects process-based probes in the shared inference template. Kubernetes
therefore never polls `/health`.

Idle worker records expire from Redis after five minutes. Once they expire, the
external HPA metric no longer has an accurate ranker-capacity baseline.

The hosted HPA also uses the shared 75-second scale-up stabilization window and
a target of `0.6`, which reacts too late for this service.

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
      target: 0.4
      threshold: 60000
      throughput: 60000
      upCooldown: 15
```

The target controls worker-occupancy scaling. The throughput values remain the
initial sizing floor. `upCooldown` shortens ranker scale-up only. The inherited
75-second cooldown still produces a 150-second scale-down stabilization window.

## Source Evidence

- `ai-server/ranker/tasks/inference.py`
- `ai-server/ranker_monitor.py`
- `ai-server/ranker_health.py`
- `ai-server/constants.py`
- `groundx-on-prem/src/groundx/templates/_helpers/app/ranker-inference.tpl`
- `groundx-on-prem/src/groundx/templates/app/inference.yaml`
- `groundx-on-prem/src/groundx/templates/resources/hpa.yaml`
- `cashbot-go/pkg/operator/metrics.go`

## Rollout

Implementation stops before deployment.

After separate approval:

1. Build and publish the ranker image.
2. Deploy to a non-production environment with one ranker replica.
3. Confirm `/alive` and `/health` pass and the external metric retains its idle
   capacity baseline for more than five minutes.
4. Apply a controlled load and confirm HPA requests a second replica before the
   first is saturated.
5. Confirm scale-down returns to one replica.
6. Promote to production in a separate operation.

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
