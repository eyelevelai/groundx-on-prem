# Ranker Inference Queue Back-Pressure HPA Tasks

## 1. Confirm Existing Pattern

- [x] Re-read repo instructions and the GroundX Studio Harness autoscaling
      guidance.
- [x] Confirm task backlog metrics default to threshold `10`.
- [x] Confirm ranker inference uses Celery queue `inference_queue`.
- [x] Confirm cashbot-go already implements the `task` metric path.
- [x] Confirm implementation must stop before deployment.

## 2. Implement Chart Change

- [x] Switch ranker inference HPA from `ranker-inference:inference` to
      `ranker-inference:task`.
- [x] Keep `ranker-inference:throughput`.
- [x] Move ranker inference config from `metrics.inference` to `metrics.task`.
- [x] Set target queue to `inference_queue`.
- [x] Set default threshold to `10`.
- [x] Render the ranker inference service name as the task metric `session`
      only when `ranker.cache.addr` selects a separate ranker cache.
- [x] Render `metrics.sessions.<ranker inference service name>` from
      `ranker.cache` when a separate ranker cache is configured.
- [x] Add `ranker.cache.isCluster` support so the metrics Redis client can use
      the same cluster/simple connection mode as existing cache overrides.
- [x] Keep the shared HPA cooldown behavior unchanged.
- [x] Mirror the changed source templates into `helm/`.
- [x] Leave ranker API HPA, ai-server, node settings, secrets, and stateful
      resources unchanged.

## 3. Validate

- [x] Add Helm test coverage for the ranker inference HPA metric names.
- [x] Add Helm test coverage for the generated `metrics.task` config.
- [x] Add Helm test coverage for ranker cache override metrics config.
- [x] Regenerate Helm snapshots with `helm unittest -u src/groundx`.
- [x] Run focused ranker Helm tests.
- [x] Run the full Helm unit test suite.
- [x] Render the chart and inspect ranker inference HPA/config output.
- [x] Run `helm lint`.
- [x] Run OpenSpec validation.
- [x] Run `git diff --check`.

## 4. Post-Approval Deployment Test Plan

- [ ] Deploy the chart change after explicit approval.
- [ ] Confirm deployed HPA and metrics server versions.
- [ ] Confirm `ranker-inference:task` is near zero at idle.
- [ ] Confirm `{celery}inference_queue` backlog explains the external metric.
- [ ] If `ranker.cache.addr` is overridden, confirm the metrics server reads the
      same Redis instance that owns `{celery}inference_queue`.
- [ ] Run a controlled ramp that exercises ranker inference.
- [ ] Watch `ranker-inference:task`, `ranker-inference:throughput`,
      `inference_queue` depth, HPA events, pending pods, GPU node readiness,
      model readiness, ranker API latency, and Lambda duration/errors.
- [ ] Tune threshold only from observed queue depth and scale-up timing.
