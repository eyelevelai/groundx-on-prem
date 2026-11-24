## Goals / Non-Goals

Goal: the default upgrade of a GPU-requesting inference Deployment completes on a node with no spare GPU, without manual steps. Non-goals: a new values key, schema or helper, a download-time guard (see proposal.md), and the harness correction (separate PR).

## Decisions

1. **Inline in `inference.yaml`, no helper.** One call site, so the GPU test lives next to `$ud`. The block is an `else if` branch after the existing `{{- if and $ud (ne $ud "") }}` explicit branch, which stays as it is and gives precedence for free.
2. **GPU test.** Read `requests` and `limits` of the rendered `$rs` with `dig`, convert with `float64`, compare `gt 0`. `float64` turns `"0"`, a non-numeric string and nil into 0, so no separate guard is needed. A missing or `null` `requests`/`limits` block must not make the template fail; the new test case removes `limits` to prove it.
3. **Strategy.** `RollingUpdate` with `maxSurge: 0`; `maxUnavailable` stays at the API default 25%, which is 1 pod at 1, 2 and 4 replicas. `RollingUpdate` rather than `Recreate` so a multi-replica install still replaces pods one at a time.
4. **Deadline.** `add (include "groundx.celeryWorker.gracePeriod" (dict "key" $entry "replicas" $rp)) 600`, the same include as `terminationGracePeriodSeconds`, so the two cannot drift. Layout and ranker give 1500; summary with a GPU request gives 900.
5. **Layout CPU mode needs no extra case in the template.** The layout helper strips the GPU request before `$rs` reaches the template, so the same test yields no strategy.
6. **Mirror.** `helm/templates/app/inference.yaml` is a byte copy; the push gate byte-compares the tree.

## Existing mechanisms

- `updateStrategy` string knob (`<svc>.inference.updateStrategy`, read at `src/groundx/templates/app/inference.yaml:43`): reused unchanged as the opt-out and the precedence rule.
- `groundx.celeryWorker.gracePeriod` (`src/groundx/templates/_helpers/app/celery-worker.tpl:5`): reused for the deadline.
- No new helper, key, flag or constant. No close existing mechanism for a GPU-quantity test: the nearest, the layout `deviceType` handling in `src/groundx/templates/_helpers/app/layout-inference.tpl`, covers layout only and strips the request, so the template tests the rendered resources instead.

## Opt-out and rollback

An explicit `updateStrategy: RollingUpdate` renders the type only. Whether Helm's patch then clears the `maxSurge` and `progressDeadlineSeconds` rendered earlier is not asserted here; no source for it was read. It is checked in the validation EKS session: upgrade with the default, upgrade again with `updateStrategy: RollingUpdate`, read `spec.strategy` and `spec.progressDeadlineSeconds` with `kubectl get deployment -o jsonpath`, and record what is observed. If the old values persist, `docs/upgrades.md` gains a line telling operators to set `Recreate` instead, and this design is amended.

## Not proven by this change's tests

Render assertions prove the manifest, not cluster behavior. Two assumptions in `contract.md` stay open until the live run on a one-GPU EKS node (ticket AC2):
- the time from the old pod releasing the GPU to the new pod Ready stays under 600 s for layout and ranker, which `+ 600` relies on;
- a Terminating pod holds its `nvidia.com/gpu` until its containers exit, so the new pod waits Pending instead of failing.

A model download on a `modelVersion` change can exceed the 600 s margin and is outside this change. The Kubernetes-controller assumptions in `contract.md` are cited there and not re-proven here.

Producer contract shapes confirmed: see `contract.md`.

## Verification

Extend the non-snapshot cases in `src/groundx/tests/inference_test.yaml` and add one case driven by `tests/files/values.inference-gpu-rollout.yaml` (layout quoted quantity with a grace override, ranker quoted zero with no limits, summary GPU with explicit `Recreate`). Hand-patch the `progressDeadlineSeconds` and `strategy` lines into the affected `inference_test.yaml.snap` and `ranker_test.yaml.snap` blocks, never `-u`. Run helm-unittest on a `mktemp -d` copy, per the repo convention. The push gate runs `.build/bin/validate-helm.sh`; no task check executes it.
