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
  check: n/a -- human cluster-verification (lookup always resolves empty under `helm template` and
  `helm unittest`; see the follow-up step below and design.md D3's limitation)
- [x] 4.2 Add `src/groundx/prereqs/storageclass/templates/NOTES.txt`: on a lookup hit where the
  supplied (normalized) `encrypted` value disagrees with the live class's `parameters.encrypted`,
  print a one-line warning that the live class's parameters are authoritative and the supplied
  value was not applied; on a lookup miss, print nothing, per design.md D4
  check: python3 -c "import importlib.util; spec=importlib.util.spec_from_file_location('vsc','.build/bin/verify-storage-contract.py'); m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m); [m.verify_notes_lookup_miss(c) for c in m.STORAGE_CHARTS]"
- [x] 4.3 Sync `templates/storageclass.yaml` and the new `templates/NOTES.txt` into the `helm/`
  mirror
  check: python3 -c "import importlib.util; spec=importlib.util.spec_from_file_location('vsc','.build/bin/verify-storage-contract.py'); m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m); m.verify_mirrors()"
- [ ] 4.4 Human cluster-verification follow-up: on a real cluster with both an already-installed
  (lookup-hit) StorageClass and a not-yet-installed (lookup-miss) name, confirm (a) `helm upgrade
  --install` against the existing class renders its live `parameters` unchanged and succeeds, and
  (b) the NOTES.txt divergence warning prints when the supplied value disagrees with the live
  class and is silent when it agrees or there is no live class
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
