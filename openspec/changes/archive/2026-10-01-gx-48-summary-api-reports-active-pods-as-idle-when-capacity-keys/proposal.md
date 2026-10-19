# GX-48: summary-api autoscaling capacity must be per process once ai-server publishes per-process records

- **Ticket**: GX-48
- **Date**: 2026-10-01

## Why

ai-server PR EyeLevel-ai/ai-server#66 changes how `summary-api` publishes its Redis capacity records:
one record set per gunicorn process (id `<HOSTNAME>-<pid>`) instead of one per pod. cashbot-go's
autoscaler computes inference throughput usage as `through / (tokensPerMinute * period * cnt)`, where
`cnt` is the number of `:total` keys it finds for the service (`pkg/operator/metrics.go:336,364-365` in
cashbot-go). With per-process records `cnt` becomes pods x workers, but the chart still gives the
`summary-api` inference entry the per-pod figure (`groundx.summary.api.threshold`, which defaults to
`2400 * threads * workers`). The autoscaler would then read throughput usage as `1/workers` of the real
value whenever `summary.api.workers` is greater than 1.

Approved by the human on 2026-10-01 (Codex agreed): make only the `summary-api` entry of the metrics
`inference:` list per process, so the per-process denominator matches the per-process record count.

## What Changes

- In `src/groundx/templates/resources/config-yaml.yaml`, the `summary-api` entry of `metrics.inference`
  renders `tokensPerMinute = max(1, threshold / workers)` using integer division, where `threshold` is
  `groundx.summary.api.threshold` and `workers` is `groundx.summary.api.workers`.
- Mirror the same change into `helm/templates/resources/config-yaml.yaml` (the two files are
  byte-identical today).
- Add one assertion case to the existing `config-yaml` tests in `src/groundx/tests/resources_test.yaml`:
  with `summary.api.workers: 2`, the `summary-api` inference value halves while the `summary-api`
  entry of `metrics.throughput` stays per pod.
- Regenerate the three snapshot cases whose fixture (`values.metadata.yaml`) already sets summary
  `workers: 2` (`metadata: resources`, and `metadata: golang` in `golang_test.yaml` and
  `metrics_test.yaml`, the latter two changing only through the config-map hash).

With `summary.api.workers: 1` (the chart default) the rendered value is unchanged.

### Explicitly out of scope

- The `metrics.throughput` entry for `summary-api` (`$sat`, divided by ready pods by cashbot-go) and the
  `groundx.summary.api.threshold` / `throughput` default helpers: unchanged.
- Any other service's metrics entry, the HPA `threshold`/`target`, or any values-schema change.
- Any ai-server or cashbot-go change (ai-server#66 is a separate PR; cashbot-go needs none).

## Capabilities

### New Capabilities
- `summary-api-capacity-metrics`: the chart's `summary-api` inference capacity value handed to the
  autoscaler is expressed per gunicorn process, floored at 1, and leaves every other metrics entry
  untouched.

### Modified Capabilities
(none)

## Impact

**Blast radius**: `src/groundx/templates/resources/config-yaml.yaml`, its `helm/` mirror,
`src/groundx/tests/resources_test.yaml`, and three snapshot cases. Every deployment's `config-yaml-map`
Secret re-renders with an identical `summary-api` inference value at the default `workers: 1`; a
deployment with `summary.api.workers > 1` gets a smaller value and its config-hash changes, so the
cashbot-go pods that mount it roll on `helm upgrade`. No values-schema change, no new resource.

**Affected environments**: any deployment with `summary.api.create` true, which in practice means
self-hosted summary. Only those running `summary.api.workers > 1` see a different rendered value.

**Compatibility and coupling (read before releasing)**: the per-process value is correct only together
with ai-server per-process capacity ids (ai-server#66, worker id `<HOSTNAME>-<pid>`).
- Chart change released before ai-server#66 reaches the cluster: records are still per pod, so
  `cnt = pods` but the denominator is divided by `workers`; the autoscaler reads throughput usage as
  `workers` times too high until the ai-server image rolls (likely over-scaling, bounded by the HPA max).
- ai-server#66 released without this chart change: `cnt = pods x workers` with the per-pod
  denominator; usage reads `1/workers` too low (likely under-scaling).
- With `workers: 1` (default) both orders are identical to today.
Release the two together. This is derived from the formula at `metrics.go:365`, not observed on a
cluster.

**Rollout**: in place via `helm upgrade`; the config-hash mechanism rolls dependants. **Rollback**:
revert the template change and its mirror; no stateful resource is touched.

**Open design questions**: none. Alternatives considered and rejected are in `design.md`.
