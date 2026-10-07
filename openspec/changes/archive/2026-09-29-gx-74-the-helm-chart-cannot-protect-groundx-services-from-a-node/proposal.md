## Why

One node drain can take a GroundX service fully offline. The chart lets an operator protect only `groundx` and the five API services with a disruption budget (a Kubernetes rule that stops a drain from evicting every pod of a service at once), and it cannot spread any service's pods across nodes. On one production cluster a single drain evicted both layout-api replicas within 2 seconds, and 3 documents were lost. The worker services (Go workers, Celery workers, metrics, inference) have no way to opt in, and their schemas reject the key.

## What Changes

- Add an opt-in `disruptionBudget.enabled` (default `false`) to the 24 services that lack it: `summaryClient`, `preProcess`, `process`, `queue`, `upload`, `largeFileDeliver`, `layoutWebhook`, `metrics`, the 13 Celery workers under `layout`, `extract` and `workspace`, and the 3 inference services. When enabled, a `policy/v1` PodDisruptionBudget with `minAvailable: 1` selects only that service's Deployment pods. The `minAvailable` value is not configurable.
- Add an opt-in `topologySpreadConstraints` list to all 30 listed services (those 24, plus `groundx` and the five API services that already have a budget). It renders as given on the pod spec and renders nothing when unset. The chart injects no `labelSelector`.
- Render spread through one new shared element helper beside the affinity, node-selector and tolerations helpers, called from the API, Go, Celery, metrics and inference renderers.
- Extend the strict `values.schema.json` with named objects for both keys (`additionalProperties: false` kept, so unknown keys still fail) and add `disruptionBudget: {enabled: false}` defaults to `values.yaml`.
- Apply every change identically to `src/groundx` and the `helm/` mirror.
- With neither setting used, `helm template` output and snapshots are unchanged. The bundled Redis StatefulSets (`cache`, `cache-metrics`) and the `schema-migration` Job stay out of scope.

Blast radius: this is additive and off by default, so no environment changes on upgrade. It affects only operators who set the new keys, and they redeploy only the services they enable. An existing install receives the feature only when it upgrades to a chart that carries it. Rollback is to unset the keys (or roll back the chart); the PodDisruptionBudget and spread settings disappear on the next render, with no data or stateful-resource impact. A budget with `minAvailable: 1` on a one-replica service blocks node drains, so it needs 2 or more replicas; this is documented in the harness follow-up, not enforced by the chart.

Open design questions: none.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `api-availability`: extends the opt-in disruption budget from `groundx` and the five API services to every long-running chart workload except the bundled Redis, and adds opt-in topology spread constraints for the same set. The default-off, strict-schema and mirrored-surface requirements extend to the new keys.

## Impact

- `src/groundx/templates/app/{api,golang,celery,metrics,inference}.yaml`, the per-service settings helpers in `src/groundx/templates/_helpers/app/`, and one new helper in `src/groundx/templates/_helpers/elements/`.
- `src/groundx/values.yaml` and `values.schema.json`, plus the `helm/` mirror of each.
- Tests: extend `src/groundx/tests/api_pdb_test.yaml` and add one case to the `helm/tests` suite; zero snapshot diff.
- No API, wire or database change. Documentation in `groundx-studio-harness` (and the regenerated `groundx-agent-harness`) is a separate follow-up in that repo, to merge after the `0.2.7` release.
