## Why

The README paragraph for the `eyelevel-gpu-summary` node (`README.md:258` at origin/0.2.8 82aa6bed) says the chart "deploys 1 pod" for summary and that it "uses 24 GB of GPU memory per worker". The chart deploys two copies by default (`summary.inference.replicas.desired: 2`, `src/groundx/values.yaml:182`), each allowed 0.48 of the GPU's memory (`summary.inference.deviceUtilize: 0.48`, `src/groundx/values.yaml:179`), and `summary-inference` requests no `nvidia.com/gpu`, so both copies share one GPU. Those defaults are sized for a 48 GB GPU. Per GX-100, an operator who follows 24 GB guidance with these defaults gets a second copy that never loads, and summary and extract requests fail. The README needs to state what the defaults need, and give tested values and an upgrade path for a 24 GB card.

## What Changes

Docs only: one paragraph in `README.md` (the `eyelevel-gpu-summary` node section) is rewritten. The chart's summary defaults are unchanged; the rewrite brings the README into line with them.

- **Default copy count.** State 2 copies, matching `summary.inference.replicas.desired`.
- **Default sizing.** State that the defaults (2 copies at `summary.inference.deviceUtilize` 0.48) are sized for a 48 GB GPU. Say "sized for", never "tested on": no 48 GB run is part of this change.
- **GPU request.** State that `summary-inference` does not request `nvidia.com/gpu` by default, so every copy scheduled to a node shares that node's GPU.
- **Per-node GPU budget.** On each summary GPU node, pods x `summary.inference.workers` x `summary.inference.deviceUtilize` must be at most 1. The defaults come to 2 x 1 x 0.48 = 0.96.
- **Tested 24 GB values.**
  - `summary.inference.replicas` `min`, `desired`, and `max` set to 1.
  - `summary.inference.workers: 1`.
  - `summary.inference.deviceUtilize: SPIKE_DEVICE_UTILIZE`.
  - `summary.inference.updateStrategy: Recreate`.
- **Applying the 24 GB values.** Apply them to a running install as an in-place `helm upgrade` with a values file. Recreate stops the old copy before starting the new one, so summary is briefly unavailable during each upgrade.
- **Scope of the 24 GB values.** They assume a dedicated summary GPU node. They were tested on AWS g5.2xlarge (NVIDIA A10G) only, with image `SPIKE_IMAGE_TAG` and helm `SPIKE_HELM_VERSION`. Other 24 GB cards (for example L4) are not covered.
- **Several nodes or HPA.** With several summary GPU nodes, or `cluster.hpa: true` with `summary.inference.replicas.max` above 1, copies can land on the same GPU. Add a GPU request through `summary.inference.resources` (`nvidia.com/gpu: 1`) or spread copies with `summary.inference.topologySpreadConstraints`. Keep `summary.inference.replicas.max` at or below the number of copies the summary GPU nodes can hold.
- **Recreate for the 48 GB defaults.** Recommend `summary.inference.updateStrategy: Recreate` for the 48 GB defaults too, as a values setting, with the same brief-downtime tradeoff. This advice is derived, not tested on 48 GB. It comes from the rolling-update arithmetic: Kubernetes' default rolling update adds one copy before it removes an old one, and 3 x 0.48 > 1. It also comes from the 24 GB run without Recreate, which the validation run records.

**Placeholders.** `SPIKE_DEVICE_UTILIZE`, `SPIKE_IMAGE_TAG` (with its digest in the evidence), and `SPIKE_HELM_VERSION` are named placeholders. They are filled from the validation run's recorded evidence (`evidence/verify.json`) before the README is written. None of them is ever guessed. The README change cannot ship while any placeholder text remains. If the validation run does not prove a first-attempt load at any value, implementation stops and escalates.

**Other "deploys 1 pod" lines.** `git grep 'deploys 1 pod' -- README.md` returns three hits. Only `README.md:258` (summary) is in scope. `README.md:234` is the layout paragraph and `README.md:246` is the ranker paragraph; both say 1 pod, which matches `layout.inference.replicas.desired: 1` (`values.yaml:257`) and `ranker.inference.replicas.desired: 1` (`values.yaml:441`). This change does not edit either paragraph.

No change to the chart, values schema, templates, helm-unittest snapshots, `helm/` mirror, or Terraform.

## Capabilities

### New Capabilities

- `summary-inference-gpu-sizing`: the README's summary-node sizing guidance must agree with the chart's summary defaults. It covers copy count, GPU size the defaults are sized for, default absence of a `nvidia.com/gpu` request, the per-node GPU budget, the tested 24 GB values and their in-place upgrade path, and the multi-node/HPA guidance.

### Modified Capabilities

None. No existing spec under `openspec/specs/` covers summary GPU sizing or the README node-sizing paragraphs.

## Impact

- **Files.** `README.md` only, in the `eyelevel-gpu-summary` paragraph (currently line 258). `README.md:199-200`, which lists 48 GB of GPU memory for the summary node, already agrees with the defaults and stays as it is.
- **Blast radius.** Merging redeploys nothing: no cluster, environment, chart package, or image changes. The guidance does affect self-hosted operators who follow it:
  - Applying the 24 GB values, or Recreate on the defaults, causes a short summary outage on each `helm upgrade` while the old copy stops and the new one loads.
  - The 24 GB values set `summary.inference.replicas.desired` to 1. The chart derives the default summary engine's `maxRequests` and `requestLimit` as 2 x `desired` (`src/groundx/templates/_helpers/engines.tpl:47-56`), so those limits drop from 4 to 2 when operators apply the values. Design decides whether the README states this.
- **Values surface relied on.** These keys are all already in the schema, and the chart renders them unchanged on origin/0.2.8:
  - `summary.inference.replicas` (`values.schema.json:910`) and `summary.inference.deviceUtilize` (`:878`).
  - `summary.inference.resources` (`:920`) and `summary.inference.topologySpreadConstraints` (`:933`).
  - `summary.inference.updateStrategy` (`:942`). It renders as `strategy.type` only when set (`templates/app/inference.yaml:58-61`).
  - `summary.inference.workers` (`:943`). It defaults to 1 (`summary-inference.tpl:265-268`).
- **Environments.** No GroundX-run dev, staging, or prod environment changes. The validation run that supplies the placeholder values uses a throwaway validation EKS cluster. Each apply, install, upgrade, or teardown there needs human approval at that time, because this repo is PRIVILEGED.
- **Data and stateful resources.** None. The documented values do not touch PVC, database, or storage settings.
- **Rollback.** Revert the README commit. For an operator who applied the values, `helm upgrade` with the overrides removed returns to the defaults; on a 24 GB card, the second copy then fails to load again. Rollforward: amend the paragraph.
- **Related work, not in this change.** The 0.96 retry in ai-server is GX-116. Layout and ranker upgrades left Pending on one-GPU nodes are GX-117. GX-99 and GX-104 are Done. The matching harness skill change ships in groundx-studio-harness as part of GX-100.

## Open design questions

None. The fix shape, the tested values (other than the value the validation run supplies), the Recreate recommendation, and the multi-node/HPA guidance were decided at the GX-100 brainstorm and plan gate (2026-10-19).
