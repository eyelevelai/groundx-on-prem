## 1. Slice 1 -- EBS StorageClass encrypts new volumes by default

- [x] 1.1 Add `parameters.encrypted: "true"` to `src/groundx/prereqs/storageclass/values.yaml` and
  `values.ebs.example.yaml`
  check: python3 .build/bin/verify-storage-contract.py
- [x] 1.2 Sync the two changed values files into `helm/prereqs/storageclass/`
  check: python3 -c "import importlib.util; spec=importlib.util.spec_from_file_location('vsc','.build/bin/verify-storage-contract.py'); m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m); m.verify_mirrors()"

## 2. Per-provisioner isolation -- `encrypted`/`kmsKeyId` never reach EFS/Azure/GKE

- [x] 2.1 Generalize `templates/storageclass.yaml`'s existing per-key provisioner filter (today
  scoped to `type` only) to a small EBS-only key set (`type`, `encrypted`, `kmsKeyId`), per
  design.md D1
  check: python3 -c "import importlib.util; spec=importlib.util.spec_from_file_location('vsc','.build/bin/verify-storage-contract.py'); m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m); [m.verify_provisioner_isolation(c) for c in m.STORAGE_CHARTS]"
- [x] 2.2 Sync `templates/storageclass.yaml` into the `helm/` mirror
  check: python3 -c "import importlib.util; spec=importlib.util.spec_from_file_location('vsc','.build/bin/verify-storage-contract.py'); m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m); m.verify_mirrors()"

## 3. Opt-out normalization -- all four false-like spellings omit the key

- [x] 3.1 Extend the template's opt-out guard so the stringified value is also compared against
  `"false"` (quoted), in addition to the existing empty-string/falsy check, per design.md D2
  check: python3 -c "import importlib.util; spec=importlib.util.spec_from_file_location('vsc','.build/bin/verify-storage-contract.py'); m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m); [m.verify_optout_normalization(c) for c in m.STORAGE_CHARTS]"

## 4. Existing-class preservation (`helm upgrade`) and the NOTES.txt divergence warning

- [x] 4.1 Add the cluster-scoped `lookup "storage.k8s.io/v1" "StorageClass" "" <name>` guard to
  `templates/storageclass.yaml`: when it hits, render the live class's `parameters` verbatim
  instead of computing them from `.Values`; when it misses, fall through to the slice-1/2/3
  defaulting path, per design.md D3
  check: helm unittest src/groundx/prereqs/storageclass
  (the lookup-hit branch is exercised by task 4.3a's suite, which mocks the live class with
  `kubernetesProvider`; `helm template` still resolves `lookup` empty, see design.md D3's limitation,
  and real-cluster confirmation is task 4.4)
- [x] 4.2 Add `src/groundx/prereqs/storageclass/templates/NOTES.txt`: on a lookup hit where any
  supplied (normalized) parameter differs from the live class's `parameters`, print a one-line warning
  that the live class's parameters are authoritative and naming each parameter that was not applied;
  on a lookup miss, print nothing, per design.md D4
  check: helm unittest src/groundx/prereqs/storageclass
- [x] 4.3 Sync `templates/storageclass.yaml` and the new `templates/NOTES.txt` into the `helm/`
  mirror
  check: python3 -c "import importlib.util; spec=importlib.util.spec_from_file_location('vsc','.build/bin/verify-storage-contract.py'); m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m); m.verify_mirrors()"
- [x] 4.3a (added in review round 1, F5) Add a `helm-unittest` suite for the storageclass chart,
  using `kubernetesProvider` to mock an existing live StorageClass: (a) an unencrypted EBS class
  preserves its exact `parameters` on render, and a class with no recorded `parameters` renders no
  `parameters` block; (b) NOTES.txt's divergence warning fires and names each parameter
  (`encrypted`, `kmsKeyId`, `type`, or a provisioner-specific one) when the supplied value differs from
  the live class, stays silent when they agree, and never reports the chart's EBS-only defaults for a
  non-EBS provisioner. Wired into `.build/bin/validate-helm.sh`.
  check: helm unittest src/groundx/prereqs/storageclass
- [x] 4.4 Human cluster-verification follow-up: confirm the above against a real cluster (`helm
  upgrade --install` against the existing class renders its live `parameters` unchanged and
  succeeds; the NOTES.txt divergence warning behavior matches). The lookup-hit branch and NOTES.txt
  divergence warning are now exercised by task 4.3a's `helm-unittest` suite, so this step is a true
  real-cluster confirmation, not the only check that exists for this behavior.
  check: n/a -- human-run, no live cluster available in this worktree (see design.md D3/D4 and
  AGENTS.md's migration/DB-gate-style human-verification pattern; this is not a DB migration, but
  the same "cannot be exercised without a live external system" reasoning applies)

## 5. Chart metadata, docs, and the generated-install pointer

- [x] 5.1 Bump `Chart.yaml` `version: 0.1.1` -> `0.1.2` in both
  `src/groundx/prereqs/storageclass/` and `helm/prereqs/storageclass/`
  check: grep -q '^version: 0.1.2$' src/groundx/prereqs/storageclass/Chart.yaml && grep -q '^version: 0.1.2$' helm/prereqs/storageclass/Chart.yaml
- [x] 5.2 Add the README storageclass upgrade note (existing classes kept as-is on real `helm
  upgrade`; `helm template`/GitOps users must set `encrypted: "false"` explicitly to keep an
  existing unencrypted class unchanged; new installs are encrypted by default; `"false"` is the
  opt-out; changing an existing class's actual encryption requires a new StorageClass)
  check: grep -q 'encrypted: "false"' README.md
- [ ] 5.3 (Optional, per proposal's own scope cut) Add a printed note in `terraform/aws/setup-eks`
  pointing at the README upgrade note -- no `STORAGE_DRIVER` logic change
  check: n/a -- documentation pointer only, no behavior change; proposal marks this "at most" and
  out of required scope

## 6. Full gate

- [x] 6.1 Run the complete storage contract gate (all of the above, plus the pre-existing PVC
  fixture / generated-install / mirror / stale-string checks) as one command
  check: python3 .build/bin/verify-storage-contract.py
- [x] 6.2 Run the full local CI-parity gate
  check: .build/bin/validate-helm.sh

## 7. Human / manual / privileged hand-off

- [ ] 7.1 Publish the bumped chart (`0.1.2`) to the public Helm bucket (`src/build.sh`, which runs
  `aws s3 cp ... s3://eyelevel-upload/helm/`) -- (awaiting human execution -- PRIVILEGED,
  maintainer-only; never performed by this pipeline or any automated step). New installs only pick
  up the new default once a human publishes the chart.
  check: n/a -- human-run, PRIVILEGED (publish rights to the public chart bucket; see
  AGENTS.md's Tier-3 privileged-operations list)

See the workspace-root `openspec/changes/age-106-improve-groundx-harness-security-never-ask-users-to-paste/`
change folder (outside this repo, at the workspace root alongside `contract.md`) for cross-service
coordination with `groundx-studio-harness` and any other deferred items for this ticket.

## Amendments

### 2026-10-01: review round 1 fixes (F1-F7)

The review round found real defects in the original render logic and test coverage. Fixed in the
same chart (`src/groundx/prereqs/storageclass/`, mirrored into `helm/prereqs/storageclass/`):

- **F1** (`templates/storageclass.yaml`): the `"false"`-string normalization guard was applying to
  every parameter key on every provisioner instead of only the EBS-only keys, silently dropping a
  legitimate non-EBS `"false"` value (e.g. EFS `ensureUniqueDirectory: "false"`). Scoped the guard
  to `$ebsOnlyKeys` membership. Added an EFS `ensureUniqueDirectory: "false"` fixture to
  `values.efs.example.yaml` and a `verify_storageclass` assertion that it survives rendering.
- **F2** (`templates/storageclass.yaml`): the `lookup` preservation branch only fired when the live
  class's `parameters` map was non-empty, so a live class with genuinely empty/omitted parameters
  fell through to the chart's new defaults on upgrade -- the exact immutable-parameter failure the
  guard exists to prevent. Changed the branch condition to `if $existing` alone, rendering a
  `parameters:` block only when `$existing.parameters` actually has entries.
- **F3** (`README.md`): added a chart-publication-status note near the top of the Persistent Storage
  section stating that only `0.1.1` is published as of this PR, and an explicit `--version 0.1.2`
  pin instruction in the upgrade note. The root workspace `contract.md` Rollout line still needs an
  orchestrator-level edit to state this sequencing dependency; this builder cannot write that file.
- **F4** (`templates/NOTES.txt`): the divergence-warning check did not look at provisioner, so an
  EFS/Azure/GKE upgrade with the chart's EBS-default merged into every provisioner's values could
  fire a false "value not applied" warning. Scoped the check to
  `eq .Values.provisioner "ebs.csi.aws.com"`.
- **F5**: added `src/groundx/prereqs/storageclass/tests/{storageclass_test.yaml,notes_test.yaml}`,
  a `helm-unittest` suite using `kubernetesProvider` to mock an existing StorageClass -- covering
  the lookup-hit parameter-preservation branch (F2) and the NOTES.txt divergence warning (F4),
  including its EBS-only scoping and the empty-live-parameters case. Wired into
  `.build/bin/validate-helm.sh` (`helm unittest src/groundx/prereqs/storageclass`; the chart has no
  `helm/` mirror test tree, consistent with the mirror's existing `tests/`-removed convention). Task
  4.4 above now covers only the true real-cluster confirmation follow-up; the lookup-hit behavior
  itself is exercised by this suite, not solely by a deferred human step.
- **F6** (minor, `.build/bin/verify-storage-contract.py`): added positive anchors (`kind:
  StorageClass`, a surviving non-gated parameter) to `verify_optout_normalization` and
  `verify_provisioner_isolation` so a regression dropping the whole `parameters` block would no
  longer still pass.
- **F7** (minor, `.build/bin/verify-storage-contract.py`): renamed
  `verify_notes_lookup_miss` to `verify_notes_lookup_miss_renders_without_warning` and added a
  positive `^NOTES:$` anchor, so the check can no longer pass vacuously on a NOTES.txt that failed
  to render at all.

All of the above were confirmed against a reverted-template control (each test fails on the
pre-fix behavior) and the full `.build/bin/validate-helm.sh` gate, which passed clean after the fix.

### 2026-10-01: review round 2 fixes

- The EFS `ensureUniqueDirectory: "false"` fixture added under F1 was removed from
  `values.efs.example.yaml` because it was an unrequested change to an operator-facing example. The
  proof that a non-EBS `"false"` value survives rendering now lives in
  `verify_non_ebs_false_value_survives` in `.build/bin/verify-storage-contract.py`, which renders
  with a temporary override file instead.
- `templates/NOTES.txt` now normalizes the live `"false"` value the same way as the supplied value,
  so a supplied `"false"` against a live `"false"` no longer warns.
- Generated-output checks now require `encrypted: "true"` for EBS and reject `encrypted` and
  `kmsKeyId` for EFS.

### 2026-10-05: lookup-miss NOTES check moved into the unit suite

Under the pinned Helm 3.19.0, `helm install --dry-run=client` contacts the cluster for its version,
so `verify_notes_lookup_miss_renders_without_warning` in `.build/bin/verify-storage-contract.py`
failed on any machine without a reachable cluster (it also picked up the machine's own kubeconfig).
It was removed. The same case is now the `EBS lookup miss (class not in the cluster)` test in
`src/groundx/prereqs/storageclass/tests/notes_test.yaml`, which runs against a mocked provider. The
verifier's helm calls also pin `KUBECONFIG` to a nonexistent file so they never read ambient cluster
credentials. The task 5.x check that named the removed function is superseded by that unit test.

### 2026-10-08: review comment fixes

- Task 4.1's check now points at the `helm-unittest` suite from task 4.3a instead of `n/a`; the suite
  exercises the lookup-hit branch with a mocked provider. Task 4.2's check and task 4.3a's text are
  aligned with the same behavior.
- The divergence warning in `templates/NOTES.txt` now compares every parameter the chart would render
  against the live class (using the same filtering as `storageclass.yaml`) and names each one that
  differs, so a changed `kmsKeyId` or `type` is reported, not only `encrypted`. EBS-only defaults are
  not reported for a non-EBS provisioner.
- Task 4.4 was confirmed on the groundx-validation EKS cluster on 2026-10-07: a real `helm upgrade`
  of a 0.1.1 class to 0.1.2 left the class unchanged and printed the warning, and a new install
  created a volume AWS reports as encrypted (an `encrypted=false` install created an unencrypted one).
- The README GitOps note is qualified: setting `encrypted: "false"` keeps a class that 0.1.1 created
  without an explicit value, but does not help a class that 0.1.1 created with an explicit
  `encrypted: "false"`, because 0.1.2 never renders an explicit `false`.
