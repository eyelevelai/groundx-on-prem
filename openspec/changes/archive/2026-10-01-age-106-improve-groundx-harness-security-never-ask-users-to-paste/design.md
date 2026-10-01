## Goals / Non-Goals

**Goals:**
- EBS-provisioned StorageClasses encrypt new volumes by default; opting out is an explicit,
  single-spelling-normalized choice.
- Non-EBS provisioners (EFS, Azure Files, GKE Filestore) never see `encrypted`/`kmsKeyId`, even
  though Helm merges the chart's new top-level defaults into every provisioner's values.
- `helm upgrade --install` against a cluster that already has the StorageClass never attempts to
  change its (immutable) `parameters`, on any provisioner.
- The `helm/` mirror and `.build/bin/verify-storage-contract.py` stay the enforced source of
  truth for all of the above, same as the chart's existing StorageClass contract.

**Non-Goals:**
- No change to `terraform/aws/setup-eks` logic beyond, at most, a printed pointer to the README
  upgrade note (proposal's own scope cut — the deprecated Terraform-only install path stays out).
- No new subsystem, table, queue, or public status lifecycle — this stays a template/values/gate
  change to one existing chart (`groundx-storageclass`).
- No change to encryption-at-rest for EFS/Azure/GKE provisioners — the proposal scopes the
  `encrypted`/`kmsKeyId` StorageClass-parameter surface to EBS only; this design does not assert
  or rely on any claim about those other provisioners' own encryption defaults.
- Publishing the bumped chart to the public Helm bucket (`src/build.sh`) is explicitly a human,
  PRIVILEGED hand-off, not part of this design's execution.

## Decisions

**Invariant (gate-class change — this modifies `.build/bin/verify-storage-contract.py`,
an existing CI gate):** the StorageClass contract verifier must reject any render where a
non-EBS provisioner's output carries `encrypted` or `kmsKeyId`, and must not reject a correct
EBS-default render or any of the four opt-out spellings that correctly omit the key. One
property — "encryption parameters never leak past the EBS provisioner boundary, and the opt-out
is spelling-insensitive" — holds regardless of which provisioner or which opt-out spelling is
under test.

### D1 — Generalize the existing per-key provisioner filter, don't add a second one
`templates/storageclass.yaml` already special-cases one key (`type`) by provisioner:
`(or (ne $key "type") (eq $.Values.provisioner "ebs.csi.aws.com"))`. Rather than adding a second,
parallel filtering mechanism for `encrypted`/`kmsKeyId`, this generalizes the same `range`/`if`
guard to a small set of EBS-only keys (`type`, `encrypted`, `kmsKeyId`), checked by membership
rather than by repeating the `ne $key "..."` clause per key. Alternative considered: a dedicated
`{{- if eq $.Values.provisioner "ebs.csi.aws.com" }}` block duplicating the whole `parameters`
render for EBS vs. non-EBS — rejected because it forks the single `range` into two copies that can
drift, which is exactly the class of defect this change exists to prevent in the gate.

### D2 — Opt-out normalization compares the stringified value, not raw truthiness
Today's guard `and $value (ne (toString $value) "")` already drops unquoted `false`/`null`/`""`
(Go template falsiness / empty-string-after-stringify) but lets the quoted string `"false"`
through, because `"false"` is a truthy, non-empty string. Fix: add `(ne (toString $value) "false")`
to the same guard, so all four spellings normalize to "key omitted" through one condition, for
every EBS-only key, not just `encrypted`. No separate opt-out code path per key.

### D3 — Existing-class preservation via `lookup`, precedent `templates/app/metrics.yaml`
`templates/app/metrics.yaml` already calls `lookup "v1" "Secret" $ns $tlsSecretName` and
`lookup "v1" "ServiceAccount" $ns $sanFinal` to branch on live-cluster state. This design reuses
the same mechanism at cluster scope: `{{- $existing := lookup "storage.k8s.io/v1" "StorageClass"
"" .Values.storageClassName }}`. When `$existing` is non-nil, the template renders
`$existing.parameters` verbatim instead of computing `parameters` from `.Values`; when nil
(no existing class, or no live cluster to query), it falls through to the new-install
defaulting path (D1/D2). **Source-read claim:** StorageClass `parameters` are immutable once the
object is created — Kubernetes public docs, "Storage Classes" concept page
(kubernetes.io/docs/concepts/storage/storage-classes/, "Parameters" section: "Parameters are
specific to the volume plugin/provisioner ... The set of parameters, once set, cannot be updated");
so a naive default-everywhere render would make the next `helm upgrade` against an already-installed
class fail at the API server, and the `lookup` guard is what avoids that failure, not best-effort
luck. Additionally, AWS EBS CSI driver `encrypted`/`kmsKeyId` are read only at volume-provision
time from the `StorageClass.parameters` block (aws-ebs-csi-driver docs,
github.com/kubernetes-sigs/aws-ebs-csi-driver, "Create StorageClass" / parameters reference) —
this is why the per-provisioner filter (D1) is the only place these two keys need to be gated:
no other code path in this chart reads or re-applies them.
**Known, documented limitation (source-read claim):** `lookup` returns an empty result under
`helm template`, `helm install --dry-run`, and GitOps renderers with no live cluster context — Helm
docs, "Chart Template Guide / Functions and Pipelines", "Using the `lookup` Function"
(helm.sh/docs/chart_template_guide/functions_and_pipelines/#using-the-lookup-function): "the lookup
function ... will always return an empty list in a `helm template` ... command" (equally true
for `--dry-run` and client-side GitOps renderers, which have no live cluster to query). So those
flows always take the new-install defaulting path, even against an already-installed class.
README upgrade note (D5) documents the explicit `encrypted: "false"` workaround for an operator on
one of those flows who wants to keep an existing unencrypted class unchanged.

### D4 — NOTES.txt divergence warning: added (not deferred), reusing the same `lookup` call
The chart has no `templates/NOTES.txt` today. This adds one, with a single conditional block: when
`$existing` is non-nil (D3's lookup hit) and the user's supplied `.Values.parameters.encrypted`
(normalized per D2) disagrees with `$existing.parameters.encrypted`, print a one-line warning that
the live class's parameters are authoritative and the supplied value was not applied. This reuses
the lookup result D3 already computes — no second cluster read, no new mechanism. Rationale for
adding rather than deferring: the review-round finding is exactly the kind of silent-mislead this
chart's own StorageClass immutability makes possible, the fix is a single conditional appended to
one new small file, and it does not touch `parameters` rendering at all (the warning is advisory
output only, not a gating check) — so it carries none of the overbuild risk the scope-discipline
guard watches for.
**Verification limitation, same as D3's lookup-hit branch:** `helm unittest`'s `lookup` resolves
empty the same way `helm template`'s does (no live cluster in either tool's render path), so the
divergence branch cannot be driven by an automated check in this repo today. The lookup-miss path
(no warning printed) is covered by an automated `helm template`/`helm-unittest` assertion; the
lookup-hit divergence-warning text itself is verified by the same manual, human cluster-verification
task as D3's lookup-hit parameter-preservation behavior (tasks.md names both under one follow-up
step, not two) — both exercise the identical untestable-in-CI lookup-hit branch, so splitting them
into two human steps would not add coverage.

### D5 — README upgrade note, Chart.yaml version bump, and `helm/` mirror sync
The storageclass section of `README.md` gains one upgrade-note paragraph covering: existing
classes are kept as-is automatically on a real `helm upgrade` (D3); `helm template`/GitOps users
must set `encrypted: "false"` explicitly to keep an existing unencrypted class unchanged (D3's
limitation); new installs are encrypted by default (D1); `"false"` (and `false`/`null`/`""`) is the
opt-out (D2); and changing an existing class's actual encryption requires creating a new
StorageClass, because `parameters` are immutable (same source-read claim as D3). `Chart.yaml`
bumps `0.1.1` → `0.1.2` in both `src/groundx/prereqs/storageclass/` and the `helm/` mirror. Every
changed file in `src/groundx/prereqs/storageclass/` (`Chart.yaml`, `values.yaml`,
`values.ebs.example.yaml`, `templates/storageclass.yaml`, the new `templates/NOTES.txt`) is copied
byte-for-byte into `helm/prereqs/storageclass/`, and `templates/NOTES.txt` is added to
`MIRRORED_FILES` in `.build/bin/verify-storage-contract.py` so `verify_mirrors()` enforces the new
file's sync the same way it already enforces the other six.

### D6 — Contract shapes live in `contract.md`, not here
The confirmed cross-service shape (the EBS `parameters` block, the opt-out spelling, the
lookup-based preservation behavior) that `groundx-studio-harness`'s on-prem skill consumes is
recorded in the workspace `contract.md` at apply time (`contract_section`), not duplicated here —
see `contract.md`'s `groundx-on-prem → groundx-studio-harness` touchpoint for the full shape.

## Risks / Trade-offs

- [Risk] An operator on `helm template`/GitOps with an already-installed unencrypted class gets a
  surprise encrypted-by-default render on their next apply, because `lookup` cannot see the live
  cluster from those tools. → Mitigation: README upgrade note (D5) states the explicit
  `encrypted: "false"` opt-out for exactly this case; this is a documented, not solved, limitation
  (per the proposal's own scope).
- [Risk] The lookup-hit branch (existing-class preservation, and the D4 divergence warning) has no
  automated test in this repo's current tooling (`helm template` and `helm unittest` both resolve
  `lookup` to empty). → Mitigation: tasks.md carries one explicit human cluster-verification
  follow-up step covering both; every other requirement (new-install defaults, per-provisioner
  isolation, opt-out normalization, lookup-miss fallback) is covered by the automated contract
  verifier.
- [Risk] Generalizing the single `range`/`if` guard (D1) instead of forking EBS vs. non-EBS
  rendering keeps the template DRY but means a future third gated key must remember to join the
  same membership check rather than inventing a parallel guard. → Mitigation: the invariant above
  and the gate's catches/must-not-block scenarios (`specs/storageclass-encryption-defaults/spec.md`)
  make a regression on this point a CI failure, not a silent drift.

## Migration Plan

- No stateful-resource migration: a template change is inert until a `helm upgrade`/`helm install`
  applies it. On an already-installed cluster, D3's `lookup` guard means `parameters` on the live
  StorageClass never actually changes, so there is no existing-install rollback surface. A fresh
  install made after this change ships encrypted by default permanently (parameters are immutable;
  changing a since-created class's actual encryption needs a new StorageClass, same as any other
  post-hoc parameter change — this is the existing Kubernetes behavior D3 cites, not new behavior
  this change introduces).
- Rollout order: merge this chart change → human-reviewed `src/build.sh` publish (PRIVILEGED,
  out of this design's scope) → new installs pick up `encrypted: "true"` once the bumped chart
  version (`0.1.2`) is published.
- Rollback: reverting the chart version restores pre-change defaults for any *new* install made
  after the revert; no existing live StorageClass is touched either way (D3 applies symmetrically).

## Open Questions

None outstanding — D1-D3 generalize an existing in-repo pattern
(`templates/storageclass.yaml`'s own per-key filter; `templates/app/metrics.yaml`'s `lookup` use),
D4 is a self-contained addition reusing D3's lookup call, and D5/D6 are mechanical (mirror sync,
version bump, contract hand-off). No `superpowers:brainstorming` session was needed, consistent
with the planner's source-of-truth note.
