# Fix Ranker Autoscaling Readiness Tasks

## 1. Confirm Scope

- [x] Re-read repo instructions and OpenSpec configuration.
- [x] Trace the external ranker metric from worker status through
      `cashbot-go/pkg/operator/metrics.go`.
- [x] Compare ranker inference probes with layout and summary inference.
- [x] Trace `ranker-api:api` from process-level request capacity through the
      cashbot-go metrics server and Helm HPA.
- [x] Confirm GPU node and Cluster Autoscaler changes are out of scope.
- [x] Confirm implementation must stop before deployment.

## 2. Add Regression Coverage

- [x] Add a Helm test that expects ranker HTTP `/alive` and `/health` probes.
- [x] Assert hosted HPA values render as min 1, max 4, target `0.7`, and
      60-second scale-up stabilization.
- [x] Run the focused Helm test and confirm it fails before the template fix.
- [x] Add a Helm test that requires ranker API to render only
      `ranker-api:api` at target `0.7`.

## 3. Implement Probe And HPA Fix

- [x] Add ranker inference port `8080` to the source chart helper.
- [x] Select the shared HTTP probe path for ranker inference.
- [x] Mirror the changed chart helper into `helm/`.
- [x] Keep the rendered HPA metric name as `ranker-inference:inference` so it
      consumes the ai-server/cashbot-go rolling busy metric.
- [x] Set hosted ranker HPA target to `0.7` and scale-up cooldown to 60 seconds.
- [x] Keep hosted ranker min 1, max 4, threshold 60000, and throughput 60000.
- [x] Set ranker API target to `0.7` and remove only its separate throughput
      metric.
- [x] Allow the ranker API target override in source and mirrored schemas.
- [x] Leave secrets, node settings, and update strategy unchanged.

## 4. Verify Worker State

- [x] Test that a malformed ranker request restores worker availability.
- [x] Test that a ranker inference exception restores worker availability.
- [x] Confirm the ranker health process uses the same worker count as the
      ranker worker process.

## 5. Validate

- [x] Regenerate Helm snapshots with `helm unittest -u src/groundx`.
- [x] Run all `ai-server` ranker tests and Python compile checks.
- [x] Run `helm lint` for source and mirror charts with hosted values.
- [x] Run the full Helm unit test suite.
- [x] Render hosted ranker resources and inspect probes, HPA metrics, and
      scale-up behavior.
- [x] Confirm changed source and mirror files match.
- [x] Validate OpenSpec strictly.
- [x] Run `git diff --check` in both repos.

## 6. Review And Handoff

- [x] Run an independent adversarial review against this OpenSpec change.
- [x] Normalize Celery task hostnames to the worker names used by health.
- [x] Keep 60-second scale-up separate from 900-second scale-down.
- [x] Resolve all in-scope findings.
- [x] Report validation evidence and remaining node-provisioning risk.
- [x] Confirm no deployment was performed before approval.

## 7. Future Rollout

- [x] Record production approval from 2026-07-25.
- [x] Use PR 47 as the single groundx-on-prem branch for ranker autoscaling and
      extract deployment changes.
- [ ] Build and publish the approved `0.2.7` ranker images.
- [ ] Deploy the approved hosted ranker values after separate approval.
- [ ] Deploy the matching cashbot-go PR 1535 metrics server before treating
      load-test output as HPA evidence.
- [ ] Confirm worker capacity remains visible after more than five idle minutes.
- [ ] Confirm `ranker-inference:inference` is explained by the cashbot-go
      rolling busy calculation before trusting the HPA result.
- [ ] Confirm ranker Redis `inference_queue` depth is monitored directly during
      the ramp.
- [ ] Confirm controlled load scales above one replica and later returns to one.
- [ ] Obtain separate approval before production deployment.
