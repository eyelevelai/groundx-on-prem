## Why

Pods can still cut off in-flight work on shutdown. Extract workers are not in a Supervisor group, so with two or more workers per family they are not stopped together. The five API pods set no gunicorn `graceful_timeout` and a pod grace that is not tied to the API's own `timeout`, so a request still running at SIGTERM can be reset. Ranker-api also waits on its Celery tasks without a bound, so a task that never finishes is only ended by the pod being killed. Separately, each Celery worker family repeats its own grace default, stop wait (grace - 30), worker programs, group section and start command across five supervisord config files, `celery.yaml` and `inference.yaml`. The repetition is how extract lost the group.

## What Changes

Blast radius: chart-only template change, rolled out as a normal `helm upgrade`. Every Deployment whose rendered pod template changes restarts once on upgrade: the extract worker Deployments (their Supervisor config gains `[group:celery_workers]`) and the five API Deployments (new default `terminationGracePeriodSeconds` and gunicorn config). Celery worker services other than extract render byte-identical to `main`, so they do not roll for this change. After rollout an API pod with a request in flight can take up to `timeout` + 30 s to stop (150 s, or 270 s for summary-api); an idle pod still stops at once. No stateful resource is touched. Rollback: revert the chart commit and upgrade; the commits are independent, so the API commit can be reverted without the shared-helper commit. Environments: every install that upgrades to the chart release carrying this change; the ai-server images ship on the same release.

Commit 1 (shared Celery worker definition, mirrored into `helm/`):
- Add one shared chart helper that owns, for every Celery worker service rendered through `celery.yaml` and `inference.yaml`: the default grace period (each service's default lives in exactly one place), the Supervisor stop wait (grace - 30, floor 1), the worker programs, the `[group:celery_workers]` section, the `export PYTHONPATH=... && exec supervisord -c .../supervisord.conf` start command, and the optional startup step as an init container (layout inference's `init-layout`).
- The five `*-supervisord-conf.yaml` files, `celery.yaml` and `inference.yaml` call the helper and no longer compute grace or stop wait themselves.
- Extract services (`extract-agent`, `extract-download`, `extract-save`) gain `[group:celery_workers]` at every worker count, including 1, so Supervisor stops all their workers together.
- Render is byte-identical to `main` for every Celery worker service, other than that extract group, on: default values; `replicas.gracePeriod` set; cache type valkey; `imageType: chainguard` (`values/chainguard/values.yaml`); worker counts of 2 or more per family; `mode: ingest`.
- The extract-agent preStop run time plus the grouped stop wait must fit inside the pod grace period. If it does not at the tested worker counts, the build escalates; changing grace, stop wait or the preStop is out of scope.
- The `download-model` init container in `inference.yaml` is not touched (GX-125 owns it).

Commit 2 (API pods, mirrored into `helm/`):
- Set gunicorn `graceful_timeout` to `groundx.<svc>.api.timeout` in the five API gunicorn configs (extract, layout, ranker, summary, workspace).
- Default the API pod `terminationGracePeriodSeconds` to `timeout` + 30 when `replicas.gracePeriod` is unset. `extract.api` and `workspace.api` keep `replicas.gracePeriod` override precedence; layout, ranker and summary `.api` still reject it. No `values.schema.json` change.
- Render `RANKER_TASK_WAIT_SECONDS` = `ranker.api.timeout` - 10 (floor 1), computed once in a chart helper, as a container env var on `ranker-api` only. It is not a `config.py` key, because `ranker-config-py-map` is shared with `ranker-inference` and a new key would change that GPU pod's config hash and roll it. This is not a secret.

Specs and tests:
- Update the living specs `worker-graceful-shutdown` (reword the summary 300 s justification, which stops being true once the ai-server summary fix ships; the value stays 300) and `layout-worker-graceful-shutdown`, and add an API shutdown capability.
- Update the helm-unittest suites and snapshots. Snapshots are hand-patched, never regenerated with `helm unittest -u`. The gate is `.build/bin/validate-helm.sh`.

Non-goals: the extract-agent preStop, any existing grace default or worker count, `pre-process`/`process`/`queue`/`summary-client`/`upload` grace and drain (GX-124, including the `drainSeconds` calculation in `config-yaml.yaml`), `acks_late`, broker visibility timeout, and the harness docs (a linked follow-up ticket is drafted at hand-off).

Cross-repo: the only contract that crosses repos is the `RANKER_TASK_WAIT_SECONDS` env var, read by the ai-server `ranker_server.py`. It is additive in both directions: an old image ignores it, and a new image without it falls back to a bounded built-in default (110 s). Both repos build in one level. See the workspace `openspec/changes/gx-142-on-prem-pods-can-still-cut-off-in-flight-work-on-shutdown/` for the cross-repo plan.

Accepted gap: extract-api, layout-api and workspace-api have no proven per-request upper bound in code; the chart `timeout` is the limit their shutdown waits cover. summary-api is bounded by its 240 s task wait and ranker-api by the new cap.

Open design questions: none.

## Capabilities

### New Capabilities
- `api-graceful-shutdown`: gunicorn `graceful_timeout`, default pod grace and the ranker-api task-wait env var on the five API pods, all derived from each API's `timeout`.

### Modified Capabilities
- `worker-graceful-shutdown`: grace default and stop wait come from one shared definition; extract workers join the Supervisor group; the summary 300 s justification is reworded and the value kept.
- `layout-worker-graceful-shutdown`: layout worker and layout-inference grace, stop wait and startup step render through the shared definition with an unchanged render.

## Impact

- Chart source: `src/groundx/templates/_helpers/app/` (new shared Celery worker helper; `ranker-api` helper gains an env var), `templates/resources/{extract,layout,ranker,summary,workspace}-supervisord-conf.yaml`, `templates/app/celery.yaml`, `templates/app/inference.yaml` (grace, init-layout and start command only), `templates/resources/*-gunicorn-conf-py.yaml` (five), `templates/app/api.yaml`.
- Mirror: the same files under `helm/templates`, byte for byte (`verify_mirrors()` in the gate).
- Tests: `celery`, `extract`, `inference`, `ranker`, `workspace`, `api` and `resources` helm-unittest suites and their snapshots.
- Specs: `openspec/specs/worker-graceful-shutdown`, `openspec/specs/layout-worker-graceful-shutdown`, new `openspec/specs/api-graceful-shutdown`.
- Related work: groundx-on-prem #164 (GX-125) edits the `download-model` block and the inference and ranker snapshots, so whichever merges second rebases; #162 (0.2.9 prep) changes the chart-version label in every snapshot if it merges first.
