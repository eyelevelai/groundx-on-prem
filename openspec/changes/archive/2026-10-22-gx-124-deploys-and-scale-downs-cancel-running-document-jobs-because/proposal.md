## Why

Deploys and scale-downs cancel running document jobs in the five Go queue services (`preProcess`, `process`, `queue`, `summaryClient`, `upload`) because the chart renders no shutdown wait for them unless an operator sets `<service>.replicas.gracePeriod`. Without a wait, Kubernetes applies its 30-second default and the app cancels running jobs on SIGTERM, so Kafka redelivers them to another pod and any work not already saved is repeated. The layout and extract workers already default to 900 seconds (GX-66); these five services should match.

## What Changes

- Add a default `gracePeriod: 900` inside each of the five `groundx.<svc>.replicas` helpers (`src/groundx/templates/_helpers/app/{pre-process,process,queue,summary-client,upload}.tpl`) when the key is absent, using the existing `if not (hasKey $in ...)` default pattern those helpers already use for `cooldown`, `hpa`, `min`, `max`. The unchanged `hasKey` guards in `golang.yaml` (`terminationGracePeriodSeconds`) and `config-yaml.yaml` (`drainSeconds`) then render `terminationGracePeriodSeconds: 900` and `drainSeconds: 870` for these five services.
- An explicit `<service>.replicas.gracePeriod` still wins, with `drainSeconds = max(1, gracePeriod - 30)` as today.
- `groundx`, `layoutWebhook` and the opt-in workers (`fileAccess`, `largeFileDeliver`, `postProcess`) get no default, because their helpers are untouched. They keep rendering no `terminationGracePeriodSeconds`.
- Mirror the five helper edits byte-identically into `helm/templates/_helpers/app/`.
- Invert the unit tests that assert the no-default behavior (`golang_test.yaml`, `resources_test.yaml`), add default and override cases, and add a negative case that `groundx` and `layoutWebhook` still render no `terminationGracePeriodSeconds`.
- Hand-patch the affected snapshots (golang, resources, metrics) in a separate commit; never `helm unittest -u` (repo AGENTS.md).
- Amend `openspec/specs/queue-service-grace-period/spec.md` through a change delta (see Capabilities).
- Location note: the ticket's preferred approach was an `else` branch in `golang.yaml` and `config-yaml.yaml` modeled on `celery.yaml`, marked "location not confirmed". The plan gate chose the replicas helpers; the rendered behavior is identical. The PR body says so in one line.
- Pre-merge validation task, not a code task: on the validation EKS, roll one of the five services with drain on while a long job is in flight, and record whether the draining pod keeps its partition, whether any message is processed by two pods at once, and whether a partition stalls. Capture before (current chart) and after (this branch) with the same method. If concurrent duplicates or stalls are confirmed, the ticket author decides whether the services' redelivery checks are safe under concurrency before merge.
- Release notes go in the PR body: the restart and the rollback, plus a paragraph a human pastes into the GitHub Release of the first release that carries this change (after 0.2.8). No new file.
- No `values.yaml`, `values.schema.json` or Chart.yaml change (Chart.yaml reads 0.2.8 on `main`; the bump for the release that carries this change belongs to release cut).

Not breaking at the values surface: the schema already accepts `gracePeriod`, and operators who set it see no change. The default is a rollout-time behavior change (see Impact).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `queue-service-grace-period`: three requirements change.
  - "No gracePeriod set - chart output stays byte-identical to today" becomes a default requirement: with `gracePeriod` unset the five services render `terminationGracePeriodSeconds: 900` and `drainSeconds: 870`, while `groundx` and `layoutWebhook` still render no `terminationGracePeriodSeconds`.
  - The "summaryClient only" sibling-absence scenario now expects the other four services to render the 900/870 default, not no `drainSeconds`.
  - "Sweep consistency across the five parallel config-yaml.yaml edits" now expects every block to render `drainSeconds` (default or derived), and the per-service override isolation stays.
  - Still unchanged: override and floor, schema acceptance, deploy-order safety, and the src/helm mirror requirement.

## Impact

- **Code**: five helper files in `src/groundx/templates/_helpers/app/` and their `helm/` copies; `src/groundx/tests/golang_test.yaml`, `resources_test.yaml`, the golang, resources and metrics snapshots; `openspec/specs/queue-service-grace-period/spec.md` via delta. `golang.yaml` and `config-yaml.yaml` are unchanged.
- **Blast radius (every environment that upgrades to the first release that carries this change, after 0.2.8, dev through prod)**: `drainSeconds` changes `config-yaml.yaml`, whose hash is the `config-hash` annotation on every `golang.yaml` Deployment (`golang.yaml#L65`), so each restarts once on upgrade. By default that is seven Deployments: `groundx`, `layout-webhook`, `pre-process`, `process`, `queue`, `summary-client`, `upload`. `metrics` (which also hashes `config-yaml.yaml`), `fileAccess`, `largeFileDeliver` and `postProcess` also restart when enabled. The schema-migration Secret embeds the same config-yaml content and gains `drainSeconds` too. No stateful resource (db, file, search, stream) is touched.
- **What could break on rollout**: rolling updates and node drains of the five services can now take up to 900 seconds when a job is running (idle pods still stop at once), so slow rollouts are expected. On node scale-down the cluster autoscaler caps the wait at its `--max-graceful-termination-sec` (600 seconds by default per the harness docs; documented only, the bundled Terraform is out of scope per the ticket author). A draining pod may keep its Kafka partition during the wait, which is the subject of the validation task. On SQS installs the default also turns on drain-time lease release in cashbot-go; the design phase confirms this is intended.
- **Rollback**: redeploy the previous chart. The services return to the 30-second Kubernetes default unless `gracePeriod` is set, and the Deployments restart once more.
- **Environments and data**: no data migration and no persisted state change. The Kafka validation task runs only on the validation EKS, never on production.
- **Docs (other repo)**: the harness on-prem docs describing `gracePeriod` for these five services are changed in `groundx-studio-harness`, with its own PR; it merges after the release that carries this change is published.
- **Gate**: `.build/bin/validate-helm.sh` plus `diff -r src/groundx/templates helm/templates`.
- **Open design questions**: none left that block the proposal. Two items are confirmed in design: that no PDB, HPA or rollout setting blocks a 900-second termination, and that SQS lease release on drain is intended.
- **Assumption**: 900 seconds covers the longest normal job in each of the five services (ticket assumption, not measured; per-service tuning is out of scope).
