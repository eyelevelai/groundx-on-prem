## Why

Whether an on-prem Go pod's in-flight work survives a stop (deploy, scale-down, node drain) depends on which of three shutdown paths it uses. On the 0.3.0 chart the 900-second queue default is copied into five helpers and `drainSeconds = gracePeriod - 30` into five config blocks, while `groundx`, `layoutWebhook`, `metrics`, `fileAccess`, `largeFileDeliver` and `postProcess` render no pod grace period or `drainSeconds`, and the schema rejects `gracePeriod` on five of them. GX-161 (Linear) asks for one shutdown rule for every Go service, written once in the chart. The cashbot-go side (signal handling and `drainSeconds` on `config.Server`) ships separately; this change is the chart half.

## What Changes

- Add one Go grace helper following the `groundx.celeryWorker.gracePeriod` / `stopWaitSecs` pattern. It holds the only default table (900 s for `preProcess`, `process`, `queue`, `summaryClient`, `upload`, `largeFileDeliver`, `postProcess`; 150 s for `groundx`, `layoutWebhook`, `fileAccess`, `metrics`) and the only `max 1 (sub grace 30)` formula.
- Every Go pod's `terminationGracePeriodSeconds` (`golang.yaml` and `metrics.yaml`) and every Go config block's `drainSeconds` (`groundxServer`, `layoutWebhookServer`, `metricsServer`, `fileAccessServer`, the five queue blocks, `largeFileDeliveryServer`, `postProcessFileServer`) come from that helper, replacing the five 900 copies and five formula copies.
- `values.schema.json` accepts an integer `gracePeriod` (minimum 1) on `groundx`, `layoutWebhook`, `metrics`, `largeFileDeliver` and `postProcess` `.replicas`, and a new top-level `fileAccess.gracePeriod` (`fileAccess.replicas` stays an integer). Invalid values are rejected.
- Overrides isolate per service (the GX-124 no-leak invariant). Existing queue-service overrides render unchanged.
- Hand-patch tests and snapshots in `src/groundx/tests/` and `helm/` separately (never `helm unittest -u`); mirror every touched file under `helm/` (the drift check, `.build/bin/verify-storage-contract.py:216`, covers `values.yaml`, `values.schema.json` and `templates/` only).
- Add a `docs/upgrades.md` release note: every Go Deployment restarts once (`config-hash`); the new behavior needs the new chart and a new cashbot-go image. File Access on a new image with an old chart (no `drainSeconds`) exits with no wait. `largeFileDeliver` and `postProcess` start draining (up to 870 s) as soon as the new chart lands, on any image with QueueServer drain, which is intended; "new chart + old image behaves as today" holds only for the four request-serving services.
- Chart and app version bumps are left to the release step.
- **Behavior change, not breaking for operators:** services that rendered no grace period now render one (150 s or 900 s). No existing value is removed or renamed.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `queue-service-grace-period`: broaden from five queue services to every Go service. The "every other Deployment keeps rendering no `terminationGracePeriodSeconds` / no `drainSeconds`" rule, the "exactly five `drainSeconds` keys" clause, the "Services outside the five render no grace period" and "a default applied in the shared template reaches a service outside the five" scenarios, and the "five separately authored stanzas / each of the five helpers sets 900" rule are superseded. Kept: override isolation and no-leak, floor at 1, schema strictness, backward compatibility, mirror.

## Impact

- **Blast radius:** every Go Deployment (`groundx`, `layout-webhook`, `metrics`, `file-access`, `pre-process`, `process`, `queue`, `summary-client`, `upload`, and the optional `large-file-deliver` and `post-process`) restarts once on upgrade because the config-hash changes. Pods stopping later than before can lengthen rollouts (up to 150 s request-serving, 900 s queue). Environments: any cluster on the 0.3.0 chart line; stateful resources are untouched.
- **Rollback / roll-forward:** revert the chart to the prior release (restores unset grace on the six services and the five 900 copies; one more restart). Operators who set a new `gracePeriod` must remove it before rolling back to a chart whose schema rejects it.
- **Code and files:** `src/groundx/templates/_helpers/app/` (new Go grace helper; five queue helpers lose their copies), `templates/app/golang.yaml`, `templates/app/metrics.yaml`, `templates/resources/config-yaml.yaml`, `values.yaml`, `values.schema.json`, `tests/`, `docs/upgrades.md`, the `helm/` mirror, and `openspec/specs/queue-service-grace-period/spec.md`.
- **Cross-service touchpoint (additive):** `config.yaml` blocks now carry `drainSeconds` for services that did not have it; cashbot-go reads it. Older cashbot-go images ignore the key for the four request-serving services; the queue-backed services already read it.
- **Out of scope:** cashbot-go code changes (separate change), ai-server, Celery and Python API settings from GX-142, GX-138, changing the 900 s queue default, harness docs (GX-162), chart version bumps.
- **Open design questions:** none. Decisions D3, D4 and D5 are approved and recorded above.
