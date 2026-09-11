## 1. Restore mode-first ordering on `src/groundx` (thin vertical slice)

This group alone makes the acceptance stubs already added to `src/groundx/tests/ranker_test.yaml`
pass and proves the fix end-to-end on the source-of-truth chart surface.

- [x] 1.1 In `src/groundx/templates/_helpers/app/ranker-api.tpl` and `ranker-inference.tpl`,
      reorder `groundx.ranker.api.create` / `groundx.ranker.inference.create` (both currently
      lines 13-24) to test `groundx.ingestOnly` **before** `hasKey $in "enabled"`, matching
      `groundx.search.create` (`src/groundx/templates/_helpers/services/search.tpl:12-16`). Do
      not touch `helm/` in this task (task 2).
  check: H="${GX_ON_PREM_HELM:-helm}"; case "$("$H" version --short 2>/dev/null)" in v3.19.0|v3.19.0+*) ;; *) echo "helm ($H) is not v3.19.0 -- set GX_ON_PREM_HELM to a v3.19.0 binary" >&2; exit 1 ;; esac; "$H" unittest -f 'tests/ranker_test.yaml' src/groundx

## 2. Mirror the fix into `helm/`

- [x] 2.1 Apply the identical hunk to `helm/templates/_helpers/app/ranker-api.tpl` and
      `ranker-inference.tpl`. `helm/` has no `tests/` tree (`.helmignore:15` excludes it from the
      package), so this is verified by rendering the mirror directly rather than `helm unittest`.
  check: H="${GX_ON_PREM_HELM:-helm}"; case "$("$H" version --short 2>/dev/null)" in v3.19.0|v3.19.0+*) ;; *) echo "helm ($H) is not v3.19.0 -- set GX_ON_PREM_HELM to a v3.19.0 binary" >&2; exit 1 ;; esac; f="$(mktemp)"; "$H" template g helm --set mode=ingest > "$f" && python3 .build/bin/verify-ingest-render.py helm "$f"; rc=$?; rm -f "$f"; exit $rc

## 3. Regenerate the affected snapshots (scoped)

- [x] 3.1 Regenerate exactly these six snapshot files, scoped by `-f` (a bare
      `helm unittest -u src/groundx` is unsafe — see `design.md`'s "full-suite regen" decision;
      it churns 9-10 unrelated files even with zero template changes). Five for the mode-first-
      ordering fix, plus `ranker_test.yaml.snap` for the `busyWindowSeconds` `.create`-
      gating correction (task 3.2):
      `H="${GX_ON_PREM_HELM:-helm}"; case "$("$H" version --short 2>/dev/null)" in v3.19.0|v3.19.0+*) ;; *) echo "helm ($H) is not v3.19.0 -- set GX_ON_PREM_HELM to a v3.19.0 binary" >&2; exit 1 ;; esac; "$H" unittest -u -f 'tests/api_test.yaml' -f 'tests/inference_test.yaml' -f 'tests/resources_test.yaml' -f 'tests/golang_test.yaml' -f 'tests/metrics_test.yaml' -f 'tests/ranker_test.yaml' src/groundx`.
      This drops the pre-existing empty-render snapshot labels
      (`'disabled: api'`, `'disabled: inference'`, `'workspace-enabled: inference'`,
      `'disabled: resources'`, `'disabled: golang'`, `'workspace-enabled: golang'` — the same set
      `.build/bin/verify-helm-snapshots.py`'s `REQUIRED_EMPTY_LABELS` names for these files).
      Manually restore each as a bare `'<label>':` line (no body) in its correct alphabetically
      sorted position (case, then surface — see `verify-helm-snapshots.py`'s
      `snapshot_label_sort_key`) before considering this done.
      check: n/a — generated golden files, never hand-edited (`helm unittest -u`); correctness is
      proved procedurally, not by an independent RED/GREEN cycle (the pre-fix baseline trivially
      "passes" against its own stale golden, so no runnable command can fail pre-implementation
      here). Verify with, in order: `python3 .build/bin/verify-helm-snapshots.py` (labels present
      and sorted) and
      `git diff --unified=0 src/groundx/tests/__snapshot__/{api,inference,resources,golang,metrics,ranker}_test.yaml.snap | grep -E "^[-+]'" | grep -vE "^[-+]'(extract|extract\.ingest|extract\.oai): "`
      (must produce **no** output — any line it prints is a label outside the three ingest-mode
      fixture families and is itself a defect; the `ranker_test.yaml.snap` change is a
      content-only diff under the existing `'cache override: ranker api':` label, not a label
      add/remove, so it produces no output here — see task 3.2's own check for that fix).

- [x] 3.2 Gate `groundx.ranker.inference.busyWindowSeconds` on `.create` in
      `ranker-inference.tpl`, matching its `.threshold`/`.throughput` siblings (mirrored into
      `helm/`), so it collapses to 0 once `ranker.inference.create` is `false` — independent of
      `mode`. This is a distinct correctness fix, not a widening of the mode-first-ordering fix
      (see `spec.md`'s "Exception, independent of `mode`" note); it is what makes task 3.1's
      sixth snapshot file (`ranker_test.yaml.snap`) necessary. The `notMatchRegex` case asserting
      `ranker-inference busyWindowSeconds` is omitted from `metrics.inference` under
      `mode: ingest` + `cluster.hpa: true` already exists in `ranker_test.yaml` (`extract.ingest:
      ranker-inference busyWindowSeconds is omitted from metrics.inference even with cluster.hpa
      enabled`).
  check: H="${GX_ON_PREM_HELM:-helm}"; case "$("$H" version --short 2>/dev/null)" in v3.19.0|v3.19.0+*) ;; *) echo "helm ($H) is not v3.19.0 -- set GX_ON_PREM_HELM to a v3.19.0 binary" >&2; exit 1 ;; esac; "$H" unittest -f 'tests/ranker_test.yaml' src/groundx

## 4. Confirm the dual-surface ingest render guard end-to-end

The guard itself was already added to `.build/bin/validate-helm.sh` in this authoring pass
(`==> Verifying ranker microservices do not render under ingest-only mode` section) and verified
RED against the unfixed templates, dual-surface (catches an unfixed `helm/` mirror independently
of a fixed `src/groundx`), and with a synthetic over-block control (see `design.md`). Its
classification logic was extracted to `.build/bin/verify-ingest-render.py` with committed fixtures
at `.build/tests/test_verify_ingest_render.py`, wired into the gate ahead of the guard (same
pattern as the existing snapshot guard). The extraction was provenance only; two later
review-round fixes then changed the guard's behavior deliberately — it now fails closed on a
forbidden-kind document whose `metadata.name` it cannot read, and its required-sibling set was
widened to five workloads (see `design.md` and `spec.md`). This task confirms it — and the rest of
the chart gate — stays green once tasks 1-3 land.

- [x] 4.1 Run the full local gate with the tasks 1-3 changes in place.
  check: H="${GX_ON_PREM_HELM:-$(command -v helm)}"; case "$("$H" version --short 2>/dev/null)" in v3.19.0|v3.19.0+*) ;; *) echo "helm ($H) is not v3.19.0 -- set GX_ON_PREM_HELM to a v3.19.0 binary" >&2; exit 1 ;; esac; mkdir -p /tmp/gx36-helm-shim && ln -sf "$H" /tmp/gx36-helm-shim/helm && PATH="/tmp/gx36-helm-shim:$PATH" .build/bin/validate-helm.sh

## 5. Annotate the now-unused `cluster.nodeLabels.gpuRanker` entry

`values/chainguard/values.yaml` sets `mode: ingest`, and `groundx.node.gpuRanker` has exactly one
consumer in the chart (`_helpers/app/ranker-inference.tpl:4`), which no longer evaluates once
tasks 1-2 land. The value is therefore inert in this preset and, left bare, tells an operator to
provision a GPU node group nothing schedules to.

Annotate it rather than delete it. A bare deletion fails `helm lint` because
`values.schema.json` marks all five `nodeLabels` keys `required` with `additionalProperties:
false`, and the only ways around that are to relax the published schema or to comment out the
whole block, which is not viable here (the other four labels differ from their schema defaults
and are still needed by `layout`/`summary`/`extract` under this file's `mode: ingest`). Relaxing
a validation rule to enable a cosmetic cleanup is a worse trade than annotating, and the comment
carries strictly more information than a deletion does: it says *why* the key is present but
unused. This mirrors how `values/extract/values.yaml:18` and `values.oai.yaml:18` already
communicate the same fact. `values.schema.json` is left untouched on both surfaces.

- [x] 5.1 Append the explanatory comment to the `gpuRanker: eyelevel-gpu-ranker` line in
      `src/groundx/values/chainguard/values.yaml` and its `helm/values/chainguard/values.yaml`
      mirror, keeping the two files byte-identical. Do not edit either `values.schema.json`.
  check: HELM="${GX_ON_PREM_HELM:-helm}"; case "$("$HELM" version --short 2>/dev/null)" in v3.19.0|v3.19.0+*) ;; *) echo "helm ($HELM) is not v3.19.0 -- set GX_ON_PREM_HELM to a v3.19.0 binary" >&2; exit 1 ;; esac; grep -q 'gpuRanker: eyelevel-gpu-ranker  # unused under mode: ingest' src/groundx/values/chainguard/values.yaml && grep -q 'gpuRanker: eyelevel-gpu-ranker  # unused under mode: ingest' helm/values/chainguard/values.yaml && diff -q src/groundx/values/chainguard/values.yaml helm/values/chainguard/values.yaml >/dev/null && git diff --quiet -- src/groundx/values.schema.json helm/values.schema.json && "$HELM" lint src/groundx -f src/groundx/values/chainguard/values.yaml >/dev/null && "$HELM" lint helm -f helm/values/chainguard/values.yaml >/dev/null

## Hand-off

Not a task in this file: see the workspace `openspec/changes/gx-36-harness-ranker-microservices-do-not-auto-disable-under-mode/tasks.md`
for the hand-off checklist — pushing the branch, opening the PR against `0.2.7` (not `main`), and
carrying two release-note items into the PR body and the 0.2.7 release notes: (1) the
destructive-upgrade note (existing `mode: ingest` installs lose the seven ranker objects, and the
two ranker HorizontalPodAutoscalers where `cluster.hpa: true` — see
`proposal.md` Blast radius for the full inventory and the volume-reclaim qualification — on the
first upgrade past published 0.2.6), and (2) the `mode: all` + `ranker.inference.enabled: false`
config-hash change from the `busyWindowSeconds` `.create`-gating correction (see `spec.md`'s
"Exception, independent of `mode`" note) — on a realistic `mode: all` install that combination
rolls eight Deployments on the next upgrade (`ranker-api` plus `groundx`, `layout-webhook`,
`pre-process`, `process`, `queue`, `summary-client` and `upload`, which hash the shared
`resources/config-yaml.yaml`), even though it is not the destructive `mode: ingest` case above.
There is no `ranker-inference` Deployment in this combination — it is the disabled one.
