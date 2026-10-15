## Why

AGE-106 requires that every application the GroundX harness scaffolds or deploys encrypts data at
rest by default, so an operator opting out is an explicit choice rather than the default state.
This service's slice is the `groundx-storageclass` Helm chart: new installs on the EBS provisioner
render with `parameters.encrypted` unset today, so EBS volumes are unencrypted unless an operator
manually adds the key. Fixing the default also has to avoid breaking `helm upgrade` against a
cluster that already has the StorageClass installed, because StorageClass `parameters` are
immutable in Kubernetes — a naive default-on-everywhere change would make every existing install's
next `helm upgrade` fail.

## What Changes

- EBS-provisioned StorageClasses default to `parameters.encrypted: "true"` for new installs
  (chart defaults in `values.yaml` and `values.ebs.example.yaml`).
- `templates/storageclass.yaml` gains a per-provisioner filter: `encrypted` and the optional
  `kmsKeyId` passthrough render only when `provisioner == ebs.csi.aws.com`. They must never reach
  EFS, Azure Files, or GKE Filestore output, even though Helm's values merge carries the chart's
  new defaults into every provisioner's values.
- Normalize the opt-out: `encrypted: "false"` (quoted), unquoted `false`, `null`, and `""` all mean
  "omit the key" — today the template already drops unquoted `false`/`null`/`""` but still renders
  a quoted `"false"` string into the manifest, which is not a usable opt-out. One behavior for all
  four spellings, for both new and existing installs.
- **Existing StorageClass preservation (new behavior, not a BREAKING change for the common
  path):** the template reads the live cluster via Helm's `lookup "storage.k8s.io/v1"
  "StorageClass" "" <name>` function (same pattern already used in
  `src/groundx/templates/app/metrics.yaml` for Secret/ServiceAccount lookups, adapted for a
  cluster-scoped, empty-namespace lookup). If the StorageClass already exists, the chart renders
  that class's current live `parameters` verbatim — ignoring the chart's new defaults and any
  user-supplied `values.yaml` — so `helm upgrade --install` against an already-installed class
  never attempts to change `parameters` and never fails on Kubernetes' immutability constraint.
  If the class does not exist, the chart renders the new defaults as normal (new-install path).
  **Known, documented limitation:** `lookup` returns empty under `helm template` / client-side
  dry-run / GitOps renderers (no live cluster to query), so those flows always render the
  new-install defaults regardless of what is actually live. An operator managing an existing
  unencrypted class through one of those flows must set `encrypted: "false"` explicitly to avoid
  an unwanted encryption-default render — this is documented in the README upgrade note, not
  solved by this change.
- Copy every changed chart file into the `helm/` manual mirror (`MIRRORED_FILES` in
  `.build/bin/verify-storage-contract.py`).
- Extend `.build/bin/verify-storage-contract.py` (the existing CI gate) to assert: EBS
  default/example/setup-eks-generated output carries `encrypted: "true"`; EFS/Azure/GKE output
  (including the chart-default-merged values) carries neither `encrypted` nor `kmsKeyId`; and
  `"false"`/`false`/`null`/`""` all render with the key omitted. `verify-storage-contract.py` uses
  `helm template`, which sees no live cluster — it exercises the new-install render path only. The
  lookup-hit (existing-class) branch is covered separately (helm-unittest with a mocked lookup, if
  feasible, wired into `.build/bin/validate-helm.sh`; otherwise recorded as a human
  cluster-verification follow-up in `tasks.md`).
- README.md storageclass section gains an upgrade note explaining: existing classes are kept
  as-is automatically on `helm upgrade` (via `lookup`); `helm template`/GitOps users must set
  `encrypted: "false"` explicitly to keep an existing unencrypted class unchanged; new installs are
  encrypted by default; `"false"` is the opt-out; and changing an existing class's actual
  encryption requires creating a brand-new StorageClass, because parameters are immutable.
- Chart version bump: `groundx-storageclass` `Chart.yaml` `0.1.1` → `0.1.2`, in both
  `src/groundx/prereqs/storageclass/` and the `helm/` mirror.
- **Out of scope:** `terraform/aws/setup-eks` (the current EKS writer) needs no logic change — at
  most it gains a printed note pointing at the README upgrade note. The deprecated legacy
  Terraform-only install path is explicitly out of scope. Publishing the bumped chart to the
  public Helm bucket (`src/build.sh`) is a **human, PRIVILEGED** hand-off — not performed by this
  change.

## Capabilities

### New Capabilities
- `storageclass-encryption-defaults`: EBS StorageClass encryption-at-rest defaults, the
  per-provisioner parameter filter, the opt-out normalization, and the existing-class preservation
  (`lookup`) behavior on `helm upgrade`.

### Modified Capabilities
(none — no existing `openspec/specs/` capability currently covers the storageclass chart's
rendering behavior)

## Impact

- **Code:** `src/groundx/prereqs/storageclass/{Chart.yaml, values.yaml, values.ebs.example.yaml,
  templates/storageclass.yaml}` and the matching `helm/prereqs/storageclass/` mirror files;
  `.build/bin/verify-storage-contract.py`; possibly `.build/bin/validate-helm.sh` (only if a
  helm-unittest suite is added for the lookup-hit branch); `README.md`.
- **Environments:** every environment that installs or upgrades the `groundx-storageclass` chart
  (eks, aks, gke, openshift, minikube) via `helm install`/`helm upgrade --install
  groundx-storageclass`, including the `terraform/aws/setup-eks`-generated EKS install flow.
- **Stateful-resource impact:** the chart template change itself is inert until applied. On
  `helm upgrade` against a cluster with an existing StorageClass, the `lookup`-based render
  intentionally leaves `parameters` unchanged, so no `helm upgrade` breaks on an existing install.
  On a fresh `helm install`, new EBS StorageClasses are created with `encrypted: "true"` by
  default; no existing PersistentVolume is touched (StorageClass parameters only apply to
  newly-provisioned volumes). No data migration, no PV/PVC changes.
- **Rollback:** reverting this chart version restores the pre-change defaults; because the
  `lookup` guard means an already-upgraded cluster's live StorageClass `parameters` never actually
  change on existing installs, rollback of the chart version has no StorageClass-level rollback
  work to perform. A fresh install made after this change ships with `encrypted: "true"`
  permanently (parameters are immutable; "rolling back" an already-encrypted class's setting
  requires creating a new StorageClass, same as any other post-hoc parameter change).
- **Rollout:** no coordinated multi-repo rollout step is required for existing clusters (the
  `lookup` guard is the rollout safety mechanism); new installs simply pick up the new default
  once the bumped chart version is published (human, PRIVILEGED hand-off, out of scope here).
- **Design questions:** none outstanding — the mechanism (per-provisioner filter + `lookup`-based
  existing-class preservation) has in-repo precedent (`templates/app/metrics.yaml`) and the
  opt-out/limitation behavior is fully specified by the ticket; no `superpowers:brainstorming`
  session needed.
