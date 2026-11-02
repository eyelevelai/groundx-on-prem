## 1. Thin slice: extract workers stop together through the shared helper (commit 1)

- [x] 1.1 Add `src/groundx/templates/_helpers/app/celery-worker.tpl` with `defaultGrace`, `gracePeriod`, `stopWaitSecs`, `group` and `command`; call it from `extract-supervisord-conf.yaml` and `celery.yaml` so extract Supervisor configs render `[group:celery_workers]` at every worker count and the Celery start command and grace come from the helper
  check: .build/bin/run-suite-on-copy.sh celery-worker-shutdown_test.yaml
- [x] 1.2 Reference `test_verify_celery_render_identity.py` in `.build/bin/validate-helm.sh` next to the other guard-script tests, so the committed identity-script counter-example tests run in the gate
  check: grep -qF test_verify_celery_render_identity.py .build/bin/validate-helm.sh

## 2. Move the remaining Celery callers onto the helper (commit 1)

- [x] 2.1 Make `layout-`, `ranker-`, `summary-` and `workspace-supervisord-conf.yaml` take grace, stop wait and group from the helper, with no literal default grace or `sub $gracePeriod 30` left in any of the five supervisord files or `celery.yaml`
  check: ! grep -nE 'dig "gracePeriod" (900|300)|sub \$gracePeriod 30' src/groundx/templates/resources/extract-supervisord-conf.yaml src/groundx/templates/resources/layout-supervisord-conf.yaml src/groundx/templates/resources/ranker-supervisord-conf.yaml src/groundx/templates/resources/summary-supervisord-conf.yaml src/groundx/templates/resources/workspace-supervisord-conf.yaml src/groundx/templates/app/celery.yaml
- [x] 2.2 Make `inference.yaml` take `terminationGracePeriodSeconds` and the start command from the helper and delete the `defaultGracePeriod` setting from `summary-inference.tpl`, leaving the `download-model` block untouched
  check: ! grep -rn 'defaultGracePeriod' src/groundx/templates
- [x] 2.3 Add `groundx.celeryWorker.initContainer` to the helper and call it from `inference.yaml` for layout inference's `init-layout`, byte-identical to today's block
  check: grep -q 'groundx.celeryWorker.initContainer' src/groundx/templates/app/inference.yaml
- [x] 2.4 Mirror every commit 1 template change into `helm/templates` and prove the Celery worker render is identical to the merge-base for every listed value combination, with the extract group as the only difference
  check: python3 .build/bin/verify-celery-render-identity.py
- [x] 2.5 Hand-patch the commit 1 snapshots (extract Supervisor config maps and extract Deployment hashes in `resources_test`, `celery_test` and any other suite the render diff shows), never `helm unittest -u`, and run the affected suites without `-u`
  check: ! git diff --quiet "$(git merge-base HEAD origin/main)" -- src/groundx/tests/__snapshot__/resources_test.yaml.snap && .build/bin/run-suite-on-copy.sh resources_test.yaml celery_test.yaml extract_test.yaml inference_test.yaml workspace_test.yaml

## 3. API pods (commit 2)

- [x] 3.1 Add `graceful_timeout = <groundx.<svc>.api.timeout>` to the five `*-gunicorn-conf-py.yaml` templates
  check: helm template r src/groundx -f src/groundx/tests/files/values.search-credentials.yaml | grep -q 'graceful_timeout = 240'
- [x] 3.2 Render `terminationGracePeriodSeconds` in `api.yaml` as `replicas.gracePeriod` when set and otherwise `timeout + 30`
  check: helm template r src/groundx -f src/groundx/tests/files/values.search-credentials.yaml -s templates/app/api.yaml | grep -q 'terminationGracePeriodSeconds: 270'
- [x] 3.3 Add `groundx.ranker.api.taskWaitSeconds` (`max(1, timeout - 10)`) and render `RANKER_TASK_WAIT_SECONDS` through a `ranker-api` settings `env` entry, on `ranker-api` only
  check: helm template r src/groundx -f src/groundx/tests/files/values.search-credentials.yaml -s templates/app/api.yaml | grep -q 'RANKER_TASK_WAIT_SECONDS'
- [x] 3.4 Mirror the commit 2 templates into `helm/templates` and run the new API suite plus the template mirror comparison
  check: .build/bin/run-suite-on-copy.sh api-shutdown_test.yaml && diff -rq src/groundx/templates helm/templates
- [x] 3.5 Hand-patch the commit 2 snapshots (gunicorn config maps, config hash annotations, API grace and `ranker-api` env in `resources_test`, `api_test`, `workspace_test`, `ranker_test`, `extract_test` and any other suite the render diff shows) and run the affected suites without `-u`
  check: ! git diff --quiet "$(git merge-base HEAD origin/main)" -- src/groundx/tests/__snapshot__/api_test.yaml.snap && .build/bin/run-suite-on-copy.sh api_test.yaml resources_test.yaml workspace_test.yaml ranker_test.yaml extract_test.yaml

## 4. Runtime proofs and gate (evidence recorded in the change folder)

- [ ] 4.1 Run the local minikube test with two busy workers in one extract-download pod and show both take SIGTERM within a few seconds and no new task starts after it, and show the previous chart fails the same test
  check: n/a — needs a local minikube cluster and a stand-in worker image; evidence recorded in the change folder (no AWS)
- [ ] 4.2 Measure the extract-agent preStop run time at 1, 2 and 3 workers on the extract image (or a stand-in with the same Celery app import) and record `5 + N * c` against the 30 second slack; escalate if any tested count reaches it
  check: n/a — needs the extract image or a stand-in running locally; measurement recorded in the change folder
- [ ] 4.3 Run the local Docker 60 second request test for each API image with the chart's rendered gunicorn config: the request completes after SIGTERM, and the previous config returns an empty reply at 30 seconds
  check: n/a — needs each private API image pulled locally; recorded as evidence before the review gate
- [ ] 4.4 Run `.build/bin/validate-helm.sh` as the pre-push gate for both commits
  check: n/a — privileged-repo gate, run by the pre-push hook and the orchestrator, not by a task check

See workspace `openspec/changes/gx-142-on-prem-pods-can-still-cut-off-in-flight-work-on-shutdown/tasks.md` for cross-service coordination and deferred items.
