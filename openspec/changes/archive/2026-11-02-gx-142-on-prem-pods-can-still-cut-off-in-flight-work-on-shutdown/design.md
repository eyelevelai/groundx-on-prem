## Goals / Non-Goals

**Goals:**
- One chart definition owns every Celery worker's grace default, stop wait, group, start command and optional init step.
- Extract workers stop together; API pods finish requests in flight for the API's own `timeout`; `ranker-api` gets a bounded task wait.
- The Celery worker render stays byte-identical to the previous chart, apart from the extract group.

**Non-Goals:**
- Extract-agent preStop, any existing grace default or worker count, GX-124's services and its `drainSeconds` calculation, `acks_late`, broker visibility timeout, the `download-model` init container (GX-125), `values.schema.json`, harness docs (linked follow-up ticket at hand-off).
- Per-request upper bounds for `extract-api`, `layout-api`, `workspace-api`: the chart `timeout` is the stated limit their waits cover (accepted gap, see proposal).

Context is in `proposal.md`. Producer contract shapes confirmed against the plan: the only cross-repo shape is the `RANKER_TASK_WAIT_SECONDS` env var, recorded in the workspace `contract.md`.

## Decisions

**Invariant.** For every Celery worker service, the grace period, stop wait, worker programs, group and start command that render after this change equal what the service's own per-file computation rendered before, and differ only by the extract group the shared definition deliberately adds. The check is the rendered output compared against the base commit, not that the helper exists or that a `stopwaitsecs` line is present.

**D1. One helper file, `templates/_helpers/app/celery-worker.tpl`.** Named templates:
- `groundx.celeryWorker.defaultGrace`, taking the settings key (`extract.agent`, `layout.inference`, `summary.inference`, `workspace.cleanup`, ...): 300 for `summary.inference`, 900 otherwise. This is the only place a default lives. The `defaultGracePeriod` entry in `summary-inference.tpl` (and its read in `inference.yaml`) and the `900`/`300` literals in `celery.yaml` and the five supervisord files go away; no test reads `defaultGracePeriod`.
- `groundx.celeryWorker.gracePeriod`: `dig "gracePeriod" <default> replicas`, as an int. `celery.yaml` and `inference.yaml` use it for `terminationGracePeriodSeconds`; the supervisord files use it through `groundx.celeryWorker.stopWaitSecs` (`max(1, grace - 30)`), so Deployment and stop wait cannot disagree. An unset value never reaches the formula (the existing "unset never floors" scenario).
- `groundx.celeryWorker.group`: `[group:celery_workers]` plus `programs=celery_worker_1,...,celery_worker_N`. Callers keep their own surrounding blank lines and indentation, which is what keeps today's bytes. Monitor and health programs stay outside the group.
- `groundx.celeryWorker.command`: takes `workDir` and whether to inherit `$PYTHONPATH`; yields `export PYTHONPATH=/app && exec supervisord -c /app/supervisord.conf` for `celery.yaml` and `export PYTHONPATH=<wd>:$PYTHONPATH && exec supervisord -c <wd>/supervisord.conf` for `inference.yaml`. `execOpts` stays in the settings as data for now (always `exec` for Celery services); the helper always emits `exec`, which is every rendered value today (`layout-inference.tpl:203`, `ranker-inference.tpl:226` and `summary-inference.tpl:282` set `exec`).
- `groundx.celeryWorker.initContainer`: renders the `init-layout` block from `inference.yaml` lines 196-237 unchanged, driven by the service's `initCommand`; `inference.yaml` calls it where the block was. The `download-model` block is not moved or edited.

**D2. Why one template for four jobs, not a macro for a whole Deployment.** The Deployments differ in many unrelated ways (probes, volumes, metrics, symlink init, PVC). Moving the whole pod template would be an overbuild with no shutdown purpose; only the shutdown-related fragments move.

**D3. Extract group at every worker count.** Extract Supervisor configs call the group helper unconditionally, so a one-worker pod renders a one-program group like the other four families. The group only changes how Supervisor signals the programs; with one program it is a no-op. The extract Deployments restart once on upgrade because `supervisord-hash` changes; all other Celery Deployments do not.

**D4. Extract-agent preStop bound.** The hook runs `celery control cancel_consumer` once per worker in sequence, then `sleep 5`, and the grace period minus the stop wait is 30 seconds (900 - 870), so the hook must finish in 30 s. Cost is `5 + N * c`, where `c` is one `python -m celery ... control` call (interpreter start, app import, Celery's default 1-second control reply timeout; `c` is image-dependent and not derivable from the chart). With the default one worker the hook has at least 20 s of slack unless `c` exceeds 25 s. `c` is measured on the extract image during the minikube two-worker run (tasks 4.x) at 1, 2 and 3 workers and recorded in the change folder; if `5 + N * c` reaches 30 s at a tested count, the build escalates, because the fix would change grace, stop wait or the preStop, all excluded here. Grouping only improves this: ungrouped, the stop waits ran one after another.

**D5. API grace and graceful_timeout.** The five gunicorn configs gain `graceful_timeout = {{ include "groundx.<svc>.api.timeout" . }}` beside `timeout`. `api.yaml` renders `terminationGracePeriodSeconds` as `replicas.gracePeriod` when the key is set (extract and workspace only, unchanged precedence) and otherwise `add (int (include (printf "groundx.%s.timeout" $entry) $)) 30`; `groundx.<entry>.timeout` exists for all five entries. Gunicorn's `timeout` is a liveness check under `UvicornWorker`, so these waits describe how long the chart lets a request run, not a hard server-side cap. No `exec` is added to the API start command: bash replaces itself with gunicorn (single trailing command), so gunicorn is PID 1.

**D6. Ranker task wait.** A helper `groundx.ranker.api.taskWaitSeconds` returns `max(1, timeout - 10)`; `ranker-api.tpl`'s settings gain `"env"` with `RANKER_TASK_WAIT_SECONDS`, which `api.yaml` already renders as container env. It stays out of `ranker-config-py-map` because that Secret is shared with `ranker-inference` and a new key would change that pod's config hash and roll the GPU pods. The name, margin (10 s) and the ai-server default of 110 are fixed by the workspace `contract.md`.

**D7. Rollout and compatibility.** Commit 1 and commit 2 are independent and revertible separately. Rollout is a normal `helm upgrade`: extract worker Deployments restart once (commit 1); the five API Deployments restart once (commit 2) and then take up to `timeout + 30` s to stop with a request in flight. The env var is additive both ways (old image ignores it, new image without it defaults to 110). Every touched template is mirrored byte for byte into `helm/templates`; commit 2 changes the five gunicorn confs, `api.yaml` and `ranker-api.tpl` in both trees. The mirror is checked by `verify_mirrors()` in the gate.

**D8. How the invariant is proven.** `.build/bin/verify-celery-render-identity.py` exports the merge-base with `origin/main` (or `GX_RENDER_BASE`), renders base and working tree for default, all-enabled (extract and workspace on), `replicas.gracePeriod` on every worker family, cache valkey, chainguard, 2 and 3 workers per family and `mode: ingest`, and compares every Celery worker Deployment and `*-supervisord-conf-map` ConfigMap byte for byte. It tolerates only the extract group (stripped and re-checked to list exactly `celery_worker_1..N`) and the `supervisord-hash` line of extract Deployments, fails closed (exit 2) on a missing helm, base or render, and fails if any of the 16 Celery services was not rendered by some combination. It also compares the `helm/` render with the `src/groundx` render. It is not wired into `validate-helm.sh`: it needs full git history and `origin/main`, which CI shallow clones may not have; it is a change-time proof whose output is recorded as evidence. Its counter-example case (a wrong shared default for summary, or an extract difference beyond the group) is committed as a unit test in `.build/tests/test_verify_celery_render_identity.py`, wired into the gate (the gate requires every `test_*.py` to be referenced in `validate-helm.sh`).

**D9. Snapshots.** Existing snapshots change only where rendered output changes (extract supervisord ConfigMaps and extract Deployment `supervisord-hash`; five gunicorn confs and their hashes; API grace; `ranker-api` env). They are hand-patched from the rendered diff and verified by running `helm unittest` without `-u` and `.build/bin/verify-helm-snapshots.py`. New cases live in two new suites, `celery-worker-shutdown_test.yaml` and `api-shutdown_test.yaml`, since helm-unittest 1.1.2 rewrites a suite's snapshot when some of its tests error.

## Risks / Trade-offs

- **Whitespace drift in moved fragments.** A helper emitting one extra blank line changes every Supervisor config hash and rolls Celery pods. Mitigation: the byte-identity script, run before each commit.
- **preStop at higher worker counts.** Unmeasured until the minikube run (D4); escalation path stated.
- **Longer API shutdown.** Pods with a request in flight take up to 150 s (270 s summary) to stop, which lengthens rolling updates and node drains; idle pods are unaffected.
- **Merge order with GX-125 (#164) and 0.2.9 prep (#162).** #164 edits the `download-model` block and inference/ranker snapshots; whichever merges second rebases. #162 changes the chart-version label in all snapshots.
- **Hand-patched snapshots** can encode a wrong value; the render diff and the unmodified `helm unittest` run are the cross-check.

## Amendments

### 2026-11-02

`execOpts` and `$eopts` were removed in review round 1 with the render unchanged. This supersedes D1's "execOpts stays in the settings" and, for commit 1, D7's "commit 1 and commit 2 are independent and revertible separately": the shared Celery helper change and the `execOpts` removal must be reverted together (see the rollback amendment in `proposal.md`).

`.build/bin/verify-celery-render-identity.py` is not run by the CI gate: CI uses a shallow checkout and the script needs the pre-change base. Run it by hand whenever someone edits the shared Celery helper. Only its unit tests run in `validate-helm.sh`.
