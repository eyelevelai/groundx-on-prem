## Why

GX-124 gave the five always-rendered Go queue services (`preProcess`, `process`, `queue`, `summaryClient`, `upload`) a 900-second termination grace period and an 870-second `drainSeconds` by default. The optional `largeFileDeliver` and `postProcess` workers run the same queue-server code but render neither, so when an operator enables one, Kubernetes applies its 30-second default and the app cancels running jobs on SIGTERM instead of waiting for them. They were left out of GX-124 only because they are optional and off by default in this chart.

## What Changes

- Default `gracePeriod` to 900 in `groundx.largeFileDeliver.replicas` and `groundx.postProcess.replicas` (`src/groundx/templates/_helpers/app/large-file-deliver.tpl`, `post-process.tpl`) and the byte-identical `helm/` copies. The existing presence guard in `app/golang.yaml` then renders `terminationGracePeriodSeconds`.
- Render `drainSeconds` of `gracePeriod - 30`, floored at 1, in the `largeFileDeliveryServer` and `postProcessFileServer` blocks, in the same helper files that already build those blocks.
- Add `gracePeriod` (`type: integer`, `minimum: 1`) to both workers' `replicas` blocks in `src/groundx/values.schema.json` and `helm/values.schema.json`.
- Extend `golang_test.yaml`, `resources_test.yaml` and `post-process_test.yaml` with default, override and schema cases. Hand-patch the six snapshot entries that render an enabled worker (no `-u`).
- Add a `replicas.gracePeriod` row to `docs/agents/large-file-delivery.md` and a sentence to `docs/agents/post-processing.md`.

Behavior change: with a worker enabled and no `gracePeriod` set, its Deployment renders `terminationGracePeriodSeconds: 900` and its config block renders `drainSeconds: 870`. With both workers disabled (the default) the render is byte-identical to before.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `queue-service-grace-period`: adds a requirement that the enabled optional workers default to the same grace period, and scopes the "exactly five `drainSeconds` keys" scenario, the "every other Deployment renders no grace period" sentence and the sweep-consistency invariant so they no longer cover the two enabled workers.

## Impact

- Code: the two helper files and their `helm/` copies, the schema in both chart copies, three test files, two snapshot files, two docs, the spec.
- Affected installs: those with `largeFileDeliver.enabled` or `postProcess.enabled` (both off by default). Because the config Secret changes, every `golang.yaml` Deployment of such an install restarts once through `config-hash`.
- Rollback: revert the change; the workers return to the 30-second Kubernetes default unless `gracePeriod` is set.
- Not affected: hosted cloud, where both workers run as AWS Lambdas and the chart is not used.
- Out of scope: cashbot-go, the cluster autoscaler cap, measuring job durations.
- Open design questions: whether 900 seconds covers the longest post-process job is unconfirmed; no job duration was found for it.
