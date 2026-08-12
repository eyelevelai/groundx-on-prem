## 1. Thin slice — `summaryClient` grace period end-to-end (schema → k8s field → drain seconds)

- [ ] 1.1 RED: add a `helm-unittest` schema-validation case asserting
      `summaryClient.replicas.gracePeriod: 900` is accepted by `values.schema.json`; run it
      and confirm it fails today (`additionalProperties: false` rejects the unknown key).
- [ ] 1.2 GREEN: add `"gracePeriod": { "type": "integer" }` to `summaryClient.replicas` in
      `src/groundx/values.schema.json`, keeping `additionalProperties: false`; re-run 1.1 and
      confirm it passes.
- [ ] 1.3 RED: add a case to `src/groundx/tests/golang_test.yaml` (`set:
      summaryClient.replicas.gracePeriod: 900`, `documentSelector` on the `summaryClient`
      Deployment, `equal` on `spec.template.spec.terminationGracePeriodSeconds` = `900`); run
      it and confirm it fails (field absent today).
- [ ] 1.4 GREEN: edit `src/groundx/templates/app/golang.yaml` to render
      `terminationGracePeriodSeconds` from `$rp`'s `gracePeriod`, guarded by
      `and $rp (hasKey $rp "gracePeriod")` (mirrors `templates/app/celery.yaml:73-76`,
      omitting its `extract`-only default-900 branch — see design.md decision 2); re-run 1.3
      and confirm it passes.
- [ ] 1.5 RED: add a case to `src/groundx/tests/resources_test.yaml` (`set:
      summaryClient.replicas.gracePeriod: 900`, `documentSelector` on the `config-yaml-map`
      ConfigMap, assert the `summaryServer` block's `drainSeconds` equals `870`); run it and
      confirm it fails (`drainSeconds` absent today).
- [ ] 1.6 GREEN: edit `src/groundx/templates/resources/config-yaml.yaml`'s `summaryServer`
      block to compute its own replicas dict (`groundx.summaryClient.replicas`) and render
      `drainSeconds: {{ int (max 1 (sub (int (get $rep "gracePeriod")) 30)) }}` guarded by
      `hasKey`, placed alphabetically between `baseURL` and `maxConcurrent` (design.md
      decision 3); re-run 1.5 and confirm it passes.
- [ ] 1.7 Add the "catches" sweep-consistency case (spec.md `queue-service-grace-period`):
      with only `summaryClient.replicas.gracePeriod` set, assert the other four
      `config-yaml.yaml` blocks (`preProcessFileServer`/`processFileServer`/
      `queueFileServer`/`uploadFileServer`) do NOT contain `drainSeconds`; confirm it passes
      (no leak) now that 1.6 is scoped to `summaryServer` only.
- [ ] 1.8 Add the below-margin edge case: `summaryClient.replicas.gracePeriod: 10` →
      `drainSeconds: 1` (floored, not negative); confirm it passes.
- [ ] 1.9 Run `helm unittest src/groundx` scoped to `golang_test.yaml` and
      `resources_test.yaml`; confirm all new cases pass and no existing `matchSnapshot`
      fixture (none of which set `gracePeriod`) diffs.

## 2. Widen to the remaining four Go queue services (`process`/`upload`/`queue`/`preProcess`)

- [ ] 2.1 RED: add schema-validation cases (mirrors 1.1) for `process.replicas.gracePeriod`,
      `upload.replicas.gracePeriod`, `queue.replicas.gracePeriod`, and
      `preProcess.replicas.gracePeriod`; confirm each fails today.
- [ ] 2.2 GREEN: add `gracePeriod` to the `process`/`upload`/`queue`/`preProcess` `replicas`
      blocks in `values.schema.json` (same shaped edit as 1.2, four more sites); re-run 2.1
      and confirm all pass.
- [ ] 2.3 Add cases to `golang_test.yaml` asserting `terminationGracePeriodSeconds` renders
      correctly and independently for each of the four services when only that service sets
      `gracePeriod` — these should already pass without further `golang.yaml` changes, since
      1.4's guard is presence-gated and the shared template loops over all Go services in one
      pass (design.md decision 2); run them to confirm, do not skip verifying just because no
      code change is expected here.
- [ ] 2.4 RED: add cases to `resources_test.yaml` for each of `preProcessFileServer`/
      `processFileServer`/`queueFileServer`/`uploadFileServer` (mirrors 1.5, one service's
      `gracePeriod` set at a time); confirm each fails (no `drainSeconds` render yet for
      these four blocks).
- [ ] 2.5 GREEN: edit the `preProcessFileServer`/`processFileServer`/`queueFileServer`/
      `uploadFileServer` blocks in `config-yaml.yaml` the same way as 1.6 — each with its own
      local replicas variable name (not shared across blocks, per design.md decision 3's
      copy-paste-risk note); re-run 2.4 and confirm all pass.
- [ ] 2.6 Add the "must not block" sweep-consistency case: all five services set distinct
      `gracePeriod` values simultaneously; assert every one of the five `config-yaml.yaml`
      blocks renders its own correct `drainSeconds`, independent of the other four.
- [ ] 2.7 Repeat the "catches" case from 1.7 with a different single service isolated (e.g.
      only `preProcess.replicas.gracePeriod` set) to confirm no cross-contamination
      regardless of which service is the one set.

## 3. No-op / negative coverage

- [ ] 3.1 Add an explicit case (at least one service) asserting that with no `gracePeriod`
      set, neither `terminationGracePeriodSeconds` nor `drainSeconds` renders anywhere in
      that service's output — a negative assertion, not just an unchanged snapshot.
- [ ] 3.2 Run `helm unittest src/groundx` on the full `golang_test.yaml` and
      `resources_test.yaml` suites; confirm every existing `matchSnapshot` fixture (`default`,
      `empty`, `aws`, `openshift`, `minikube`, `existing`, `metadata`, `disabled`, etc. — none
      of which set `gracePeriod`) is byte-identical to its pre-change snapshot.

## 4. Regenerate snapshots and sync the `helm/` mirror

- [ ] 4.1 Run `helm unittest -u src/groundx` to regenerate
      `tests/__snapshot__/golang_test.yaml.snap` and `tests/__snapshot__/resources_test.yaml.snap`.
- [ ] 4.2 Review the resulting `git diff` on both `.snap` files: confirm the only changes are
      the snapshots for newly-added test cases (the ones added in groups 1–3) and that no
      pre-existing snapshot entry changed — a diff on an existing entry is the regression
      spec.md's no-op requirement forbids.
- [ ] 4.3 Copy the edited `src/groundx/values.schema.json` to `helm/values.schema.json`.
- [ ] 4.4 Copy the edited `src/groundx/templates/app/golang.yaml` to
      `helm/templates/app/golang.yaml`.
- [ ] 4.5 Copy the edited `src/groundx/templates/resources/config-yaml.yaml` to
      `helm/templates/resources/config-yaml.yaml`.
- [ ] 4.6 `diff` each of the three `src/groundx/`↔`helm/` file pairs; confirm all three diffs
      are empty.

## 5. Verify (the repo's quality gates)

- [ ] 5.1 `helm lint src/groundx` — clean.
- [ ] 5.2 `helm unittest src/groundx` — green (this is the CI gate,
      `.github/workflows/helm-tests.yml`, and the only check that guards template changes).
- [ ] 5.3 `helm template src/groundx -f src/groundx/values/minikube/values.yaml` — renders
      cleanly.
- [ ] 5.4 Re-run the `src/groundx`↔`helm/` mirror `diff` from 4.6 one more time after all
      edits are final; confirm still empty.

Notes (not tasks — see the relevant overlay):

- `.build/bin/validate-helm.sh --junit` (which runs `helm lint` for both chart surfaces,
  `helm unittest`, the snapshot label guard, the workspace/storage contract verifiers, and
  targeted render checks for both chart surfaces) is the full production gate run by CI
  (`helm-tests.yml`) and by the orchestrator — it is not re-implemented as a manual task
  here, but 5.1–5.4 exercise the subset relevant to this change ahead of that run.
- No expand/contract split applies to this change: it is purely additive (a new optional
  schema key + a new presence-guarded template branch), with no old shape being deprecated
  or removed.
- See the workspace `openspec/changes/fra-114-summary-client-hpa-scale-down-interrupts-in-flight-large/tasks.md`
  (or equivalent cross-repo coordination record) for the cashbot-go delivery-coupling note
  (Ben C1: "the cashbot-go drain change and the chart grace-period change need to land
  together") — that is cross-service coordination, not a task in this repo's tasks.md.
