# Tasks — GX-66: Layout workers drain on pod termination

Checks run from the repo root. Helm commands use `"${GX_ON_PREM_HELM:-helm}"`; point `GX_ON_PREM_HELM` at a helm v3.19.0 binary. No check runs a bare `helm unittest src/groundx`, uses `-u`, or prints a rendered manifest.

Mirror rule: every template change under `src/groundx/` is copied byte-for-byte into `helm/` in the same task, and the two `values.schema.json` files are edited identically.

Commit plan: template, schema and test changes in one commit; the hand-patched `__snapshot__` blocks in a separate commit (group 3).

## Rollout sequence (no manual operations, no secret changes)

1. Run the end-to-end shutdown test on the validation cluster first, from the rendered chart, before the release is cut.
2. Release the chart with 0.2.7; upgrading restarts the six layout Deployments once.
3. Merge the `groundx-studio-harness` documentation PR only after chart 0.2.7 is published.

## 1. Thin slice: the five layout Celery workers end to end

- [ ] 1.1 Accept `gracePeriod` (integer, minimum 1) under `layout.correct`, `layout.map`, `layout.ocr`, `layout.process` and `layout.save` `replicas` in `src/groundx/values.schema.json` and `helm/values.schema.json`, keeping the property order and leaving `layout.api` unchanged
  check: H="${GX_ON_PREM_HELM:-helm}"; for c in src/groundx helm; do "$H" template t "$c" --set layout.correct.replicas.gracePeriod=100 --set layout.map.replicas.gracePeriod=110 --set layout.ocr.replicas.gracePeriod=130 --set layout.process.replicas.gracePeriod=140 --set layout.save.replicas.gracePeriod=150 --show-only templates/app/celery.yaml >/dev/null || exit 1; if "$H" template t "$c" --set layout.map.replicas.gracePeriod=0 --show-only templates/app/celery.yaml >/dev/null 2>&1; then exit 1; fi; done; cmp src/groundx/values.schema.json helm/values.schema.json
- [ ] 1.2 Render the drain settings for the five layout Celery workers: in `templates/app/celery.yaml` extend the extract-only 900-second default and `exec` conditions to the `layout` map prefix, and in `templates/resources/layout-supervisord-conf.yaml` set `stopwaitsecs` to `max(1, gracePeriod - 30)` (900 when unset) inside each `celery_worker_N` program only; mirror both into `helm/templates/`; retarget the `celery_test.yaml` case "non-extract workers keep their existing startup command" from `layout-correct` to `workspace-workspace` using `./files/values.workspace.enabled.yaml`, and rename it "workspace workers keep their existing startup command"
  check: H="${GX_ON_PREM_HELM:-helm}"; c=$("$H" template t src/groundx --show-only templates/app/celery.yaml) && [ "$(printf '%s\n' "$c" | grep -c 'terminationGracePeriodSeconds: 900')" -eq 5 ] && [ "$(printf '%s\n' "$c" | grep -c '&& exec supervisord')" -eq 5 ] && [ "$("$H" template t src/groundx --show-only templates/resources/layout-supervisord-conf.yaml | grep -c 'stopwaitsecs=870')" -eq 6 ] && diff -r src/groundx/templates helm/templates

## 2. layout-inference

- [ ] 2.1 Render the drain settings for `layout-inference`: accept `gracePeriod` under `layout.inference.replicas` in both schema files; in `templates/app/inference.yaml` render `terminationGracePeriodSeconds` (`dig "gracePeriod" 900`) only when the map prefix is `layout`; change `execOpts` in `templates/_helpers/app/layout-inference.tpl` to `python /app/init-layout.py && exec`; mirror the templates into `helm/templates/`
  check: H="${GX_ON_PREM_HELM:-helm}"; "$H" unittest -f tests/layout_shutdown_test.yaml src/groundx && "$H" unittest -f tests/layout_grace_period_test.yaml helm && diff -r src/groundx/templates helm/templates && cmp src/groundx/values.schema.json helm/values.schema.json

## 3. Snapshots and the full gate

- [ ] 3.1 Hand-patch the affected `src/groundx/tests/__snapshot__/*.snap` blocks (layout Deployments: command, `terminationGracePeriodSeconds`, `supervisord-hash`; layout Supervisor config maps; `layout-inference` documents) from the diff a plain `helm unittest` prints, never with `-u`, in a commit separate from group 1 and 2; `workspace_test`, `ranker_test`, `extract_test` snapshots and the ranker and summary documents must show no diff; then run the full gate
  check: d=$(mktemp -d) && ln -s "${GX_ON_PREM_HELM:?set GX_ON_PREM_HELM to a helm v3.19.0 binary}" "$d/helm" && PATH="$d:$PATH" bash .build/bin/validate-helm.sh; rc=$?; unlink "$d/helm"; rmdir "$d"; exit "$rc"

## 4. Hand-off notes

- [ ] 4.1 Record in the PR body: the rollout restart of the six layout Deployments, the `Recreate` note for `layout-inference`, the autoscaler caveat (effective grace is the smaller of `gracePeriod` and the autoscaler's `--max-graceful-termination-sec`), which snapshot blocks changed and why, the test-to-production line ratio, and the runtime proof from the local Docker and validation-cluster runs (those runs are not committed and have no check here)
  check: n/a — PR text; the runtime proof layers run outside the pipeline and are recorded in the PR body
- [ ] 4.2 Return the two-worker (`layout.map.workers: 2`) runtime result to the main loop as an escalation before touching the layout config; on the main loop's decision, record the outcome in `design.md` decision 8, and if the decision is to group the `celery_worker` programs, mirror the change and give it its own test case and check before ticking
  check: n/a — the outcome is decided by the uncommitted runtime test and the main loop; a group change, if decided, is behavioral and gets a real check at that point

See workspace `openspec/changes/gx-66-terminating-layout-workers-can-delay-page-work-for-an-hour/tasks.md` for cross-service coordination and deferred items (the `groundx-studio-harness` documentation PR, held until chart 0.2.7 is published, and the ranker, summary and workspace workers tracked in GX-91).
