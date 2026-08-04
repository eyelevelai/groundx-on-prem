# Ranker Inference Windowed Busy HPA Tasks

## 1. Confirm Existing Pattern

- [x] Re-read repo instructions and the GroundX Studio Harness autoscaling
      guidance.
- [x] Confirm ranker inference uses Celery queue `inference_queue`.
- [x] Confirm queue backlog is too sensitive for this workload.
- [x] Confirm point-in-time inference availability sampling can miss pressure
      between metric polls.
- [x] Confirm implementation must stop before deployment.

## 2. Implement Cross-Repo Metric

- [x] Add ai-server busy start/finish recording on ranker inference worker
      unavailable/available transitions.
- [x] Write completed busy milliseconds into short Redis buckets.
- [x] Keep active start keys for in-flight work so unfinished requests count.
- [x] Add cashbot-go reader support for `busyWindowSeconds` inference metrics.
- [x] Keep non-windowed inference services on the existing instantaneous
      availability behavior.

## 3. Implement Chart Change

- [x] Keep ranker inference HPA on `ranker-inference:inference`.
- [x] Default ranker inference throughput to `0`.
- [x] Suppress the ranker inference throughput HPA metric when throughput is
      `0`.
- [x] Preserve explicit nonzero throughput overrides.
- [x] Render ranker inference under `metrics.inference` with
      `busyWindowSeconds: 60`.
- [x] Omit ranker busy metrics and writer config when ranker inference HPA is
      disabled.
- [x] Remove ranker inference from `metrics.task`.
- [x] Do not render a ranker-specific metrics session for the busy metric.
- [x] Pass `metricsBusyWindowSeconds` to ranker ai-server config.
- [x] Default the HPA target to `0.5`.
- [x] Render `ranker.api.batchSize` into ranker config and default it to `3`.
- [x] Mirror the changed source templates into `helm/`.
- [x] Leave ranker API HPA, node settings, secrets, and stateful
      resources unchanged.

## 4. Validate

- [x] Add Helm test coverage for the ranker inference HPA metric names.
- [x] Add Helm test coverage for the generated `metrics.inference` busy config.
- [x] Add Helm test coverage that ranker busy config is omitted when HPA is
      disabled.
- [x] Add Helm test coverage that ranker cache override does not render a
      separate metrics task session.
- [x] Add ai-server unit coverage for busy start/finish bucket writes.
- [x] Add ai-server unit coverage that monitor offline events do not create busy
      intervals.
- [x] Add cashbot-go unit coverage for bucket/start reading and metric compute.
- [x] Regenerate Helm snapshots with `helm unittest -u src/groundx`.
- [x] Run focused ranker Helm tests.
- [x] Run the full Helm unit test suite.
- [x] Render the chart and inspect ranker inference HPA/config output.
- [x] Run `helm lint`.
- [x] Run `git diff --check`.
- [x] Run `npx --yes @fission-ai/openspec@1.3.1 validate
      fix-ranker-inference-hpa-readiness --strict`.

## 5. Post-Approval Deployment Test Plan

- [x] Deploy the chart change after explicit approval.
- [x] Confirm deployed HPA and metrics server versions.
- [x] Confirm `ranker-inference:inference` is near zero at idle.
- [x] Confirm busy start/bucket Redis keys explain the external metric.
- [x] If `ranker.cache.addr` is overridden, confirm the metrics server reads the
      metrics cache while ranker search/Celery uses the ranker cache.
- [x] Run a controlled ramp that exercises ranker inference.
- [x] Watch `ranker-inference:inference`, busy Redis keys, HPA events, pending
      pods, GPU node readiness, model
      readiness, ranker API latency, and Lambda duration/errors.
- [x] Tune `busyWindowSeconds` or HPA target only from observed scale timing.

Live canary result: batch size `3` with HPA target `0.5` scaled earlier than
`0.6`, preserved successful response score hashes, and still showed that
`min=1` cannot hide GPU/model warm-up during burst traffic.
