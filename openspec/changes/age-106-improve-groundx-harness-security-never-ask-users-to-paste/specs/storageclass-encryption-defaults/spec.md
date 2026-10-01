## ADDED Requirements

### Requirement: EBS StorageClass encrypts new volumes by default
The `groundx-storageclass` chart SHALL render `parameters.encrypted: "true"` for a
`provisioner: ebs.csi.aws.com` StorageClass whenever no live StorageClass of that name already
exists, without requiring the operator to set anything. Polarity: finalize success.

#### Scenario: New EBS install renders encrypted parameter by default
- **WHEN** `helm template`/`helm install` renders the chart's default values (or the EBS example
  values) for a StorageClass that does not already exist on the target cluster
- **THEN** the rendered manifest's `parameters` block includes `encrypted: "true"`

#### Scenario: Default encryption is not silently dropped
- **WHEN** the chart renders a new-install EBS StorageClass with no `encrypted` override supplied
- **THEN** the rendered manifest does NOT omit the `encrypted` key and does NOT render
  `encrypted: "false"`

### Requirement: Encryption parameters never reach non-EBS provisioners
The chart SHALL render `encrypted` and `kmsKeyId` only when `provisioner == ebs.csi.aws.com`, even
though Helm's values merge carries the chart's new top-level defaults into the EFS, Azure Files,
and GKE Filestore example values. Polarity: reject before state (the parameter is rejected before
it is ever rendered into a non-EBS manifest).

#### Scenario: EFS/Azure/GKE renders omit encryption parameters despite default merge
- **WHEN** the EFS, Azure Files, or GKE Filestore example values are rendered together with the
  chart's new `encrypted`/`kmsKeyId` defaults merged in by Helm
- **THEN** the rendered manifest's `parameters` block contains neither `encrypted` nor `kmsKeyId`

#### Scenario: Non-EBS rendering does not depend on an explicit opt-out
- **WHEN** an EFS, Azure Files, or GKE Filestore values file does not itself set `encrypted` or
  `kmsKeyId` to any value (relying only on the chart default merge)
- **THEN** the provisioner filter still omits both keys -- the result does not depend on the
  non-EBS values file explicitly opting out

### Requirement: Opt-out normalization treats all false-like spellings as "omit the key"
The chart SHALL treat `encrypted: "false"` (quoted string), unquoted `false`, `null`, and `""` as
equivalent: all four normalize to omitting the `encrypted` key from the rendered manifest, for
both new installs and existing-class renders. Polarity: reject before state (no `encrypted` key is
created in rendered state for any of the four opt-out spellings).

#### Scenario: Quoted "false" string opts out
- **WHEN** `parameters.encrypted` is set to the quoted string `"false"`
- **THEN** the rendered manifest's `parameters` block omits the `encrypted` key entirely (it does
  NOT render the literal string `encrypted: "false"`)

#### Scenario: Unquoted false opts out
- **WHEN** `parameters.encrypted` is set to unquoted `false`
- **THEN** the rendered manifest's `parameters` block omits the `encrypted` key entirely

#### Scenario: null opts out
- **WHEN** `parameters.encrypted` is set to `null`
- **THEN** the rendered manifest's `parameters` block omits the `encrypted` key entirely

#### Scenario: Empty string opts out
- **WHEN** `parameters.encrypted` is set to `""`
- **THEN** the rendered manifest's `parameters` block omits the `encrypted` key entirely

### Requirement: Existing StorageClass is preserved on `helm upgrade` via Helm `lookup`
The chart SHALL read the live cluster via `lookup "storage.k8s.io/v1" "StorageClass" "" <name>`
before rendering `parameters`. When the named StorageClass already exists, the chart SHALL render
that class's current live `parameters` verbatim, ignoring the chart's new defaults and any
user-supplied values, so `helm upgrade --install` never attempts to change immutable `parameters`
on an existing class. When the class does not exist, the chart renders the new-install defaults
(the requirements above). Polarity: finalize failure (an upgrade against an existing class must
not finalize as if the new/changed `parameters` took effect -- the live object's parameters are
what persists).

#### Scenario: Lookup miss (new install) renders chart defaults
- **WHEN** `lookup` finds no existing StorageClass of the given name (the common case under
  `helm template`, a dry run, or a true first install)
- **THEN** the chart renders `parameters` from its own defaults/values exactly as specified by the
  requirements above (no live-class short-circuit)

#### Scenario: Lookup hit (existing class) preserves live parameters, not chart defaults
- **WHEN** `lookup` finds an existing StorageClass of the given name with live `parameters` that
  differ from the chart's new defaults (e.g. an unencrypted EBS class from before this change)
- **THEN** the rendered manifest's `parameters` block matches the live class's current parameters,
  not the chart's new defaults or any changed `values.yaml` input -- the upgrade does not attempt
  to change `parameters` and does not fail on Kubernetes' StorageClass-parameter immutability

#### Scenario: Backward compatibility during rollout -- `helm template`/GitOps limitation is explicit
- **WHEN** the chart is rendered via `helm template`, a client-side dry run, or a GitOps renderer
  with no live cluster to query (so `lookup` always returns empty, even against an
  already-installed class)
- **THEN** the chart renders the new-install defaults (same as a lookup miss) and the README
  upgrade note documents that an operator managing an existing unencrypted class through one of
  these flows must set `encrypted: "false"` explicitly to avoid an unwanted encryption-default
  render -- old (unencrypted) behavior for an already-installed class is preserved automatically
  only on a real `helm upgrade` against a live cluster, not under these renderers

### Requirement: Storage contract verifier enforces per-provisioner encryption isolation and opt-out normalization
`.build/bin/verify-storage-contract.py` (the existing CI gate) SHALL assert: the EBS
default/example/`setup-eks`-generated render carries `encrypted: "true"`; the EFS/Azure/GKE
renders (including with the chart-default merge) carry neither `encrypted` nor `kmsKeyId`; and all
four false-like opt-out spellings render with the key omitted. This is a gate-class change
(modifies an existing CI gate's assertions) -- it carries the must-catch / must-not-block pair.

#### Scenario: Catches -- a regressed per-provisioner filter leaking `encrypted` into EFS/Azure/GKE
- **WHEN** the per-provisioner filter is missing or regressed, so an EFS, Azure Files, or GKE
  Filestore render carries `encrypted: "true"` (leaked from the chart's new top-level default via
  Helm's values merge)
- **THEN** `.build/bin/verify-storage-contract.py` fails (non-zero exit) and reports the leaked
  `encrypted` parameter for that provisioner

#### Scenario: Must not block -- correct per-provisioner isolation and opt-out all pass
- **WHEN** EBS renders `encrypted: "true"` by default, EFS/Azure/GKE renders omit `encrypted` and
  `kmsKeyId` entirely, and each of the four opt-out spellings (`"false"`/`false`/`null`/`""`)
  renders with the key omitted
- **THEN** `.build/bin/verify-storage-contract.py` passes (exit 0) -- the gate does not flag any of
  these legitimate renders
