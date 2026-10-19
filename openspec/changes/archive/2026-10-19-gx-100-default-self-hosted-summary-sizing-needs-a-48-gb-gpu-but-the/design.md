## Goals / Non-Goals

Motivation and current state are in `proposal.md`; requirements are in `specs/summary-inference-gpu-sizing/spec.md`.

**Goals:**
- The `eyelevel-gpu-summary` README section agrees with the chart's summary defaults on copy count, GPU size, and GPU request.
- An operator with one 24 GB summary GPU gets values that the GX-100 validation run proved, and a tested way to apply them to a running install.
- Operators with several summary GPU nodes or `cluster.hpa: true` know how to keep copies off a shared GPU.

**Non-Goals:**
- Any change to the chart, values schema, templates, snapshots, the `helm/` mirror, or Terraform. Defaults stay at 2 copies x 0.48 with no `nvidia.com/gpu` request.
- The layout and ranker paragraphs (`README.md:234`, `:246`). The ranker paragraph's "does not claim the GPU" wording disagrees with `ranker.inference.resources` on 0.2.8; that is recorded as an unrelated finding in the workspace plan, not fixed here.
- The README's HPA section (`README.md:645-706`); the summary section carries the summary-specific cap.
- The ai-server 0.96 retry (GX-116) and the layout/ranker Pending upgrade stall (GX-117).

## Decisions

### D1. One paragraph, sibling phrasing, copy count derived from values

Rewrite only the `###### eyelevel-gpu-summary` section body. Keep the sibling paragraphs' shape ("assumes an NVIDIA GPU with ... It deploys N pods ...") so the three GPU sections read alike, and say `deploys 2 pods` with `summary.inference.replicas.desired` named. The acceptance check reads N from `src/groundx/values.yaml` with `yq` rather than a typed `2`, so a later default change without a README change fails the check.

Alternative considered: a new subsection or a separate sizing doc under `docs/agents/`. Rejected: the ticket's acceptance criterion is about this README line, and a second location would be a second place to drift.

### D2. State the per-node GPU budget, not a per-worker GB figure

The section states: on each summary GPU node, pods x `summary.inference.workers` x `summary.inference.deviceUtilize` must be at most 1; defaults give 2 x 1 x 0.48 = 0.96. Each worker is its own supervisord program (`src/groundx/templates/resources/summary-supervisord-conf.yaml:19-21` renders one `celery_worker_N` per worker), and each worker process loads its own model with `gpu_memory_utilization` set to `deviceUtilize` (ai-server `summary/tasks/inference.py:134,183,316` at 591b611). The chart sets a fraction, not a GB figure, so the budget is stated as a fraction; it then holds for any card size, which the old "24 GB of GPU memory per worker" did not.

### D3. 24 GB values as one copy-pasteable `yaml` block

The block sets `replicas` `min`/`desired`/`max` 1, `workers: 1`, `deviceUtilize: <proven>`, `updateStrategy: Recreate`, nested under `summary.inference`. A block an operator can drop into a `-f` file avoids four hand-typed dotted keys. The prose around it names the full dotted paths so the keys are greppable.

### D4. Values from the validation run come only from `evidence/verify.json`

`deviceUtilize`, the image tag, the helm client version, and the instance type are filled from the `readme_values` object the orchestrator records in the workspace change folder's `evidence/verify.json` (`openspec/changes/<change>/evidence/verify.json` in the GX-100 workspace worktree, two levels above this repo's worktree). Expected shape, found anywhere in the file:

```json
{ "readme_values": { "device_utilize": "<proven value>", "image_tag": "<image ref as written in the README>", "helm_version": "<helm client version>", "instance_type": "g5.2xlarge" } }
```

The README names the tag, as the approved proposal does; the digest goes in the evidence. The tag is rebuilt in place, so the README's tested-image claim covers only the build whose digest the evidence records; a later build under the same tag is untested. The task check compares each value with the README section verbatim and fails closed when the file, the object, or a key is missing. If the run proves no first-attempt load at any value, implementation stops and escalates (proposal "Placeholders").

### D5. In-place upgrade with `-f`, and Recreate's downtime stated

The section says the values are applied with `helm upgrade` and the values file passed by `-f`, the form the validation run tested, and that Recreate stops the old copy before the new one starts, so summary is unavailable for one model load on each upgrade. It does not claim `--reuse-values` behavior, which the run does not test. Kubernetes' Recreate ordering is cited in the workspace `contract.md` (kubernetes.io Deployment docs, Recreate section).

### D6. Several nodes or HPA: GPU request first, spread second, cap always

Recommend `summary.inference.resources` with `nvidia.com/gpu: 1` first, because the scheduler then places at most one copy per GPU without any node-count arithmetic; `summary.inference.topologySpreadConstraints` second, for operators who cannot use the device plugin. Both keys exist in the schema on 0.2.7 and 0.2.8 (`values.schema.json:920,933`). Always keep `summary.inference.replicas.max` at or below the copies the summary GPU nodes hold. Keep `updateStrategy: Recreate` with a GPU request: on nodes with no spare GPU, a rolling update's extra copy would otherwise wait Pending for the GPU the old copy holds.

### D7. Recreate for the 48 GB defaults, labelled as derived

Recommend `updateStrategy: Recreate` for the defaults as a values setting. The basis is the rolling-update arithmetic (the default RollingUpdate on 2 replicas adds a copy before removing one, and 3 x 0.48 > 1; Kubernetes defaults cited in the workspace `contract.md`) plus the 24 GB negative-control run. The README says it was not tested on a 48 GB GPU.

### D8. The README does not mention the summary engine request limits

When `engines` is empty, the chart builds the default summary engine with `maxRequests` and `requestLimit` = 2 x `summary.inference.replicas.desired` (`src/groundx/templates/_helpers/engines.tpl:46-56`). The 24 GB values set `desired` to 1, so those limits drop from 4 to 2. The README does not say this, because:
- The ratio stays the same: the chart keeps the limit at 2 per copy, the same as each default copy gets, so operators have no setting to change.
- It applies only when `engines` is unset (`engines.tpl:46`). Operators who define `engines` set their own limits, and this change does not touch those limits.
- What operators can see is the copy count, which the section already states (one copy instead of two). Naming an internal derived limit in a node-sizing paragraph adds a value to keep correct without adding an action.

Alternative considered: one sentence stating that the default engine's limits drop from 4 to 2. Rejected for the reasons above.

### D9. No ADR

This is a reversible docs change with no hard-to-reverse decision; an ADR is not warranted.

### D10. Gate: the repo's own `validate-helm.sh`, plus a README-only scope assertion

No new test machinery. `.build/bin/validate-helm.sh` (helm v3.19.0, the CI pin) already covers `README.md`: `verify-storage-contract.py` `verify_no_stale_strings` reads it, `validate-helm.sh` greps it for retired workspace wording, and `git diff --check` checks whitespace in uncommitted edits. The scope assertion (`git diff --name-only origin/0.2.8` outside `openspec/` lists only `README.md`) also catches a helm-unittest snapshot rewritten by an unpinned helm during the gate run.

## Rollout & blast radius

- **Ordering:** none. Docs only; the groundx-on-prem PR targets `0.2.8` and is independent of the harness PR.
- **Environments:** nothing redeploys on merge. No GroundX-run dev, staging, or prod change; no chart package or image change.
- **Operators who follow the guidance:** applying the 24 GB values, or Recreate on the defaults, causes a short summary outage on each `helm upgrade` while the old copy stops and the new one loads. With the 24 GB values, summary runs one copy, so summary capacity is one copy's worth.
- **Stateful resources:** none touched. The summary model PVC (`summary-inference.tpl:166-178`) is unchanged; Recreate does not change its access mode.
- **Rollback:** revert the README commit. An operator returns to the defaults with `helm upgrade` without the overrides; on a 24 GB card the second copy then fails to load again.

## Risks / Trade-offs

- [The proven `deviceUtilize` is image- and vLLM-version-specific] → The README names the tested image tag and helm client version, and the workspace plan requires the evidence to record the digest and vLLM version. A future image needs its own run before the README claims it.
- [The 24 GB claim might be read as covering all 24 GB cards] → The section limits it to AWS g5.2xlarge (A10G) and names L4 as not covered.
- [Recreate costs a summary outage per upgrade] → Stated next to the recommendation so operators can choose RollingUpdate on spare GPU capacity instead.
- [The evidence file is written by the orchestrator, outside this repo] → The task check fails closed if it is missing, so the README cannot pass GREEN with guessed values.
- [The published 0.2.7 chart and 0.2.8 have the same summary defaults and keys] → No version caveat is needed (proposal "Values surface relied on"). If 0.2.8 changes a summary default before release, the D1 check fails.

## Open Questions

None. The validation run supplies the remaining values.
