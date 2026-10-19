## ADDED Requirements

### Requirement: README summary copy count matches the chart default

The `###### eyelevel-gpu-summary` section of `README.md` SHALL state the default number of `summary-inference` pods as the value of `summary.inference.replicas.desired` in `src/groundx/values.yaml` (2 at origin/0.2.8), using the phrasing of the sibling node paragraphs (`deploys 2 pods`), and SHALL name `summary.inference.replicas.desired` as the key that sets it. The section SHALL NOT say `deploys 1 pod`. The layout and ranker paragraphs, whose `deploys 1 pod` matches `layout.inference.replicas.desired` and `ranker.inference.replicas.desired`, SHALL stay unchanged.

Validated by: extracting the section with `awk` and comparing it against `yq '.summary.inference.replicas.desired' src/groundx/values.yaml`.

#### Scenario: Copy count is derived from values.yaml [finalize success]
- **GIVEN** `src/groundx/values.yaml` sets `summary.inference.replicas.desired` to N
- **WHEN** the `eyelevel-gpu-summary` section of `README.md` is read
- **THEN** it contains `deploys N pods` and names `summary.inference.replicas.desired`
- **AND** it does not contain `deploys 1 pod`

#### Scenario: Stale single-pod wording is caught [reject before state]
- **GIVEN** the summary section still says `deploys 1 pod` (the origin/0.2.8 text)
- **WHEN** the copy-count check runs
- **THEN** the check exits non-zero

#### Scenario: Layout and ranker paragraphs are left alone [skip unrelated repair path]
- **WHEN** the change is applied
- **THEN** `README.md` still contains exactly two `deploys 1 pod` lines (the layout and ranker paragraphs)
- **AND** neither paragraph is edited

### Requirement: README states what the default summary values need

The summary section SHALL state that the default summary values are sized for an NVIDIA GPU with 48 GB of GPU memory, worded as "sized for", never as tested on 48 GB. It SHALL state that `summary-inference` does not request `nvidia.com/gpu` by default, so every copy scheduled to a node shares that node's GPU. It SHALL state the per-node GPU budget: on each summary GPU node, pods x `summary.inference.workers` x `summary.inference.deviceUtilize` must be at most 1, and with the defaults this is 2 x 1 x 0.48 = 0.96. The section SHALL NOT keep the stale claim that summary uses 24 GB of GPU memory per worker.

#### Scenario: Default sizing and GPU-sharing facts are present [finalize success]
- **WHEN** the summary section is read
- **THEN** it contains `48 GB`, `nvidia.com/gpu`, `summary.inference.deviceUtilize`, `summary.inference.workers`, the `summary.inference.deviceUtilize` default from `values.yaml` (`0.48`), and the default budget `0.96`
- **AND** it does not contain `per worker` (the stale "24 GB of GPU memory per worker" claim)

### Requirement: README gives tested values for a 24 GB summary GPU

The summary section SHALL give the values for a single 24 GB summary GPU as a copy-pasteable `yaml` block: `summary.inference.replicas` `min`, `desired`, and `max` set to 1, `summary.inference.workers: 1`, `summary.inference.deviceUtilize` set to the value the GX-100 validation run proved loads on the first attempt, and `summary.inference.updateStrategy: Recreate`. It SHALL say these values are applied to a running install as an in-place `helm upgrade` with the values file passed by `-f`, and that Recreate stops the old copy before the new one starts, so summary is briefly unavailable during each upgrade. It SHALL state the tested scope: a dedicated summary GPU node, AWS `g5.2xlarge` (NVIDIA A10G) only, the summary-inference image tag and helm client version used in the run, and that other 24 GB cards (for example L4) are not covered.

Every value in that block and in the tested-scope sentence that comes from the validation run (`deviceUtilize`, image tag, helm client version, instance type) SHALL match the `readme_values` object recorded in the workspace change folder's `evidence/verify.json`. No `SPIKE_` placeholder text SHALL ship.

#### Scenario: 24 GB values match the validation evidence [finalize success]
- **GIVEN** `evidence/verify.json` records `readme_values` with `device_utilize`, `image_tag`, `helm_version`, and `instance_type`
- **WHEN** the summary section is read
- **THEN** it contains `deviceUtilize: <device_utilize>`, `<image_tag>`, `<helm_version>`, and `<instance_type>` verbatim
- **AND** it contains `updateStrategy: Recreate` and `helm upgrade`

#### Scenario: Unproven values are not shipped [reject before state]
- **GIVEN** `evidence/verify.json` is absent, or has no `readme_values`, or a value is missing from it
- **WHEN** the evidence check runs
- **THEN** it exits non-zero
- **AND** a summary section that still contains `SPIKE_` fails the content check

### Requirement: README covers several summary GPU nodes and autoscaling

The summary section SHALL tell operators that with several summary GPU nodes, or with `cluster.hpa: true` and `summary.inference.replicas.max` above 1, copies can land on the same GPU; that they should add a GPU request through `summary.inference.resources` (`nvidia.com/gpu: 1`) or spread copies with `summary.inference.topologySpreadConstraints`; and that `summary.inference.replicas.max` should stay at or below the number of copies the summary GPU nodes can hold.

#### Scenario: Multi-node and HPA guidance is present [finalize success]
- **WHEN** the summary section is read
- **THEN** it names `cluster.hpa`, `summary.inference.replicas.max`, `summary.inference.resources`, and `summary.inference.topologySpreadConstraints`

### Requirement: README recommends Recreate for the 48 GB defaults as derived advice

The summary section SHALL recommend `summary.inference.updateStrategy: Recreate` for the 48 GB defaults as a values setting, with the same brief-downtime tradeoff, and SHALL say this advice is derived from the rolling-update arithmetic (Kubernetes' default rolling update adds a copy before removing one, and 3 x 0.48 > 1) and from the 24 GB run without Recreate, not tested on a 48 GB GPU.

#### Scenario: Recreate advice for the defaults is labelled as untested on 48 GB [finalize success]
- **WHEN** the summary section is read
- **THEN** it recommends `Recreate` for the default values and states it was not tested on a 48 GB GPU
- **AND** it does not claim the defaults were tested on a 48 GB GPU

### Requirement: The chart and its gate are unchanged

The change SHALL edit only `README.md` outside `openspec/`. The chart (`src/groundx/`, `helm/`), values schema, templates, helm-unittest snapshots, and Terraform SHALL be unchanged, so existing installs render identically. The repo gate `.build/bin/validate-helm.sh`, run with helm v3.19.0, SHALL pass; it covers `README.md` through its stale-string scan (`.build/bin/verify-storage-contract.py` `verify_no_stale_strings`), its README wording checks, and `git diff --check` on uncommitted edits.

#### Scenario: Gate passes and the diff is README-only [finalize success]
- **GIVEN** the chart at origin/0.2.8
- **WHEN** `.build/bin/validate-helm.sh` runs with helm v3.19.0
- **THEN** it exits 0
- **AND** `git diff --name-only origin/0.2.8 -- . ':(exclude)openspec'` lists only `README.md`

#### Scenario: A rewritten snapshot or chart edit is caught [reject before state]
- **GIVEN** a gate run or edit that leaves any file other than `README.md` changed outside `openspec/` (for example a helm-unittest snapshot rewritten by an unpinned helm)
- **WHEN** the scope check runs
- **THEN** it exits non-zero
