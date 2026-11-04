## MODIFIED Requirements

### Requirement: README states what the default summary values need

`README.md` SHALL state the 48 GB default sizing and warn that the default does not fit 24 GB, and link `docs/upgrades.md#summary-gpu-sizing` for the full configuration and rollout details.

The Summary GPU sizing section in `docs/upgrades.md` SHALL state that the default summary values are sized for an NVIDIA GPU with 48 GB of GPU memory, worded as "sized for", never as tested on 48 GB. It SHALL state that `summary-inference` does not request `nvidia.com/gpu` by default, so every copy scheduled to a node shares that node's GPU. It SHALL state the per-node GPU budget: on each summary GPU node, pods x `summary.inference.workers` x `summary.inference.deviceUtilize` must be at most 1, and with the defaults this is 2 x 1 x 0.48 = 0.96. The section SHALL NOT keep the stale claim that summary uses 24 GB of GPU memory per worker.

#### Scenario: Default sizing and GPU-sharing facts are present [finalize success]
- **WHEN** the linked Summary GPU sizing section in `docs/upgrades.md` is read
- **THEN** it contains `48 GB`, `nvidia.com/gpu`, `summary.inference.deviceUtilize`, `summary.inference.workers`, the `summary.inference.deviceUtilize` default from `values.yaml` (`0.48`), and the default budget `0.96`
- **AND** it does not contain `per worker` (the stale "24 GB of GPU memory per worker" claim)

### Requirement: README gives tested values for a 24 GB summary GPU

The Summary GPU sizing section in `docs/upgrades.md` SHALL give the values for a single 24 GB summary GPU as a copy-pasteable `yaml` block: `summary.inference.replicas` `min`, `desired`, and `max` set to 1, `summary.inference.workers: 1`, `summary.inference.deviceUtilize` set to the value the GX-100 validation run proved loads on the first attempt, and `summary.inference.updateStrategy: Recreate`. It SHALL say these values are applied to a running install as an in-place `helm upgrade` with the values file passed by `-f`, and that Recreate stops the old copy before the new one starts, so summary is briefly unavailable during each upgrade. It SHALL state the tested scope: a dedicated summary GPU node, AWS `g5.2xlarge` (NVIDIA A10G) only, the summary-inference image tag and helm client version used in the run, and that other 24 GB cards (for example L4) are not covered.

Every value in that block and in the tested-scope sentence that comes from the validation run (`deviceUtilize`, image tag, helm client version, instance type) SHALL match the `readme_values` object recorded in the workspace change folder's `evidence/verify.json`. No `SPIKE_` placeholder text SHALL ship.

#### Scenario: 24 GB values match the validation evidence [finalize success]
- **GIVEN** `evidence/verify.json` records `readme_values` with `device_utilize`, `image_tag`, `helm_version`, and `instance_type`
- **WHEN** the linked Summary GPU sizing section in `docs/upgrades.md` is read
- **THEN** it contains `deviceUtilize: <device_utilize>`, `<image_tag>`, `<helm_version>`, and `<instance_type>` verbatim
- **AND** it contains `updateStrategy: Recreate` and `helm upgrade`

#### Scenario: Unproven values are not shipped [reject before state]
- **GIVEN** `evidence/verify.json` is absent, or has no `readme_values`, or a value is missing from it
- **WHEN** the evidence check runs
- **THEN** it exits non-zero
- **AND** a summary section that still contains `SPIKE_` fails the content check

### Requirement: README covers several summary GPU nodes and autoscaling

The Summary GPU sizing section in `docs/upgrades.md` SHALL tell operators that with several summary GPU nodes, or with `cluster.hpa: true` and `summary.inference.replicas.max` above 1, copies can land on the same GPU; that they should add a GPU request through `summary.inference.resources` (`nvidia.com/gpu: 1`) or spread copies with `summary.inference.topologySpreadConstraints`; that `summary.inference.replicas.max` should stay at or below the number of copies the summary GPU nodes can hold; and that, because every copy mounts the one summary model volume claim, whose access mode, class and name default to `cluster.pvAccessMode`, `cluster.pvClass` and `summary-model` unless `summary.inference.pvc` overrides them (`src/groundx/templates/_helpers/app/summary-inference.tpl`, `groundx.summary.inference.pvc`), copies on more than one node need ReadWriteMany storage for that claim, set with `summary.inference.pvc.access: ReadWriteMany` and a ReadWriteMany class in `summary.inference.pvc.class`. The section SHALL NOT tell operators to change `cluster.pvAccessMode` for this, because that re-specs every chart claim. It SHALL say that an existing claim cannot change its access mode, so an existing install also sets a new `summary.inference.pvc.name` and the model is downloaded again into the new claim; and that with ReadWriteOnce storage summary should stay on one node.

#### Scenario: Multi-node and HPA guidance is present [finalize success]
- **WHEN** the linked Summary GPU sizing section in `docs/upgrades.md` is read
- **THEN** it names `cluster.hpa`, `summary.inference.replicas.max`, `summary.inference.resources`, and `summary.inference.topologySpreadConstraints`

#### Scenario: Several-nodes guidance states the model volume access-mode requirement [finalize success]
- **GIVEN** every summary copy mounts the one summary model volume claim, whose access mode and name come from `summary.inference.pvc` over the `cluster.pvAccessMode` and `summary-model` defaults
- **WHEN** the several-nodes paragraph of the summary section is read
- **THEN** it says copies on more than one node need ReadWriteMany storage and names `summary.inference.pvc.access: ReadWriteMany`, `summary.inference.pvc.class`, and `summary.inference.pvc.name` (for an existing install)
- **AND** it says that with ReadWriteOnce storage summary stays on one node
- **AND** it does not contain `cluster.pvAccessMode: ReadWriteMany`

#### Scenario: Spreading copies across nodes without the storage caveat is caught [reject before state]
- **GIVEN** the several-nodes paragraph recommends spreading copies across nodes but does not state the ReadWriteMany requirement (the text at 043bfd0c)
- **WHEN** the access-mode check runs
- **THEN** the check exits non-zero

### Requirement: README recommends Recreate for the 48 GB defaults as derived advice

The Summary GPU sizing section in `docs/upgrades.md` SHALL recommend `summary.inference.updateStrategy: Recreate` for the 48 GB defaults as a values setting, with the same brief-downtime tradeoff, and SHALL say this advice is derived from the rolling-update arithmetic (Kubernetes' default rolling update adds a copy before removing one, and 3 x 0.48 > 1) and from the 24 GB run without Recreate, not tested on a 48 GB GPU.

#### Scenario: Recreate advice for the defaults is labelled as untested on 48 GB [finalize success]
- **WHEN** the linked Summary GPU sizing section in `docs/upgrades.md` is read
- **THEN** it recommends `Recreate` for the default values and states it was not tested on a 48 GB GPU
- **AND** it does not claim the defaults were tested on a 48 GB GPU
