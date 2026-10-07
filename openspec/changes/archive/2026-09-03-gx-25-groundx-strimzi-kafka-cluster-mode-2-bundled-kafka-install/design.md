Builds on `proposal.md`'s three-axis fix (API version, field shape, namespace) — this document
covers the technical decisions the proposal left open.

## Goals / Non-Goals

**Goals:**
- Make the `groundx-strimzi-kafka-cluster` subchart and the main chart's `KafkaTopic` install
  cleanly against a current, unpinned Strimzi operator (`v1`-only).
- Preserve every other Mode-2 behavior (topic set, retention, replication semantics, bootstrap
  DNS) exactly as-is.
- Give the live-Strimzi `kind` CI job the power to catch a real installability regression that a
  render/snapshot-only gate structurally cannot — this repo's only existing template guard is
  `helm-unittest` snapshot match (`AGENTS.md`/`config.yaml` context), which the prior `v1beta2`
  chart passed while still failing to install.

**Non-Goals:**
- The air-gapped/Chainguard Strimzi image seeds (`values.strimzi.operator.yaml`,
  `values.strimzi.cluster.yaml`) — deferred, tracked in the source-of-truth pack, gated on the
  private image mirror carrying a `v1`-serving Strimzi image.
- Any change to Mode 1 (external Kafka, `stream.existing`) or Mode 3 (SQS) — neither renders a
  Kafka/KafkaNodePool/KafkaTopic resource from this path.
- Any change to the main chart's `values.schema.json` or its `namespace` (`groundx.ns`)
  resolution — only the **subchart's** namespace source moves.
- The `groundx-studio-harness` doc updates — a separate repo, a separate PR, sequenced after this
  chart's release ships (contract.md).

## Decisions

**Invariant:** every Strimzi custom resource this chart emits (`Kafka`, `KafkaNodePool`,
`KafkaTopic`) must be shaped to match exactly what the currently-installed Strimzi operator
actually serves *and reconciles to `Ready`* — not merely a shape `helm-unittest` can
snapshot-match. This change trips both the gate-class and mechanical-sweep triggers: it adds a
new CI gate (the live-Strimzi `kind` job) and it applies the same `v1beta2`→`v1` `apiVersion` edit
at 3 sites (`cluster.yaml`, `nodepool.yaml`, `stream-topics.yaml`). The invariant above is the
property both must preserve — the two spec.md scenarios under "the live-Strimzi CI job proves
reconciliation, not only render shape" encode the catches/must-not-block pair.

1. **API version: one hardcoded `v1`, no dual-API branch.** All three CRs render
   `kafka.strimzi.io/v1` unconditionally — no values-driven choice between `v1beta2`/`v1`. A
   values-gated dual-API path would let an operator silently mismatch the operator's actual
   served version (exactly this defect's shape, just parameterized instead of hardcoded); a
   single hardcoded `v1` makes the chart's Strimzi-version floor an explicit, visible constraint
   (documented in the subchart README — see decision 6) rather than a silent footgun.
   Alternative considered: keep `v1beta2` as an opt-in fallback for the 0.47.0-and-earlier
   operator the ticket's workaround recipe used — rejected: that recipe was a stopgap for this
   ticket's diagnosis, not a supported install path, and dual-API support doubles the
   unittest/live-CI surface for a version this repo does not intend to keep supporting going
   forward.

2. **Kafka CR field removal is a straight delete, no values fallback.** `spec.kafka.replicas` and
   `spec.kafka.storage` are removed from `cluster.yaml` outright — not made conditional — because
   `v1` rejects them unconditionally (spike-confirmed against Strimzi 1.2.0). Broker count and
   disk size now come only from `KafkaNodePool.spec.replicas` / `.storage.volumes[0].size`, which
   already exist and are untouched. `values.yaml`'s `cluster.storage` key is deleted (dead once
   the field it fed is gone); `cluster.replicas` is kept — it now drives only the `config` block's
   replication-factor settings, not broker count (decision 5 guards the resulting decoupling).

3. **Version/metadataVersion: render-if-set via Helm's `if`, not a placeholder default.**
   `spec.kafka.version` / `spec.kafka.metadataVersion` render only when `.Values.cluster.version`
   / `.Values.cluster.metaVersion` are non-empty; `values.yaml` ships both keys unset (no default
   string). This lets Strimzi apply its own supported-version default on every fresh install
   regardless of which operator release is running, which is exactly the second axis of this
   ticket's failure (a hardcoded `4.1.1`/`4.1` that no current Strimzi release accepts). An
   operator that needs a specific Kafka version still can — `--set cluster.version=...`.

4. **Namespace: `.Release.Namespace` on the subchart's CRs only; main chart's `groundx.ns`
   untouched.** `cluster.yaml`/`nodepool.yaml`'s `metadata.namespace` moves from the hardcoded
   `eyelevel` literal to `.Release.Namespace` — this is a subchart installed standalone (`helm
   install ... -n <ns>`, confirmed: no `dependencies:` entry in `src/groundx/Chart.yaml`, so this
   subchart is never pulled in as a chart dependency of `groundx`), so `.Release.Namespace` is the
   correct, Helm-idiomatic source for "the namespace this install actually asked for."
   `stream-topics.yaml`'s `KafkaTopic` keeps `{{ include "groundx.ns" $ | quote }}`
   (`.Values.namespace`, default `eyelevel`) exactly as today — it is a main-chart template, and
   `groundx.stream.serviceHost` (`_helpers/services/stream.tpl:79`) already builds the bootstrap
   DNS host from that same `groundx.ns` value. Moving `KafkaTopic` to `.Release.Namespace` too
   would only be correct if the main chart and the subchart were always installed into the same
   Helm release — they are not (two separate `helm install` invocations per the ticket's own
   recipe) — so the fix is documented as an operational pairing constraint (decision 6), not a
   second namespace-source change.

5. **Replication-factor guard: `fail` in the template, not a silent derive.** The Linear body
   named two options — derive the replication-factor config from `nodepool.replicas`, or add a
   values guard. Deriving would silently change `cluster.replicas`' meaning (today it drives
   *both* broker count and replication factor; after this change broker count is
   `nodepool.replicas` only) without the operator ever being told the two values now mean
   different things. A `fail` in `cluster.yaml` when `.Values.cluster.replicas` is greater than
   `.Values.nodepool.replicas` (checked in `_helpers`, invoked from `cluster.yaml`) keeps
   `cluster.replicas` an independently meaningful value while refusing to emit a `Kafka` CR whose
   replication factor the broker count cannot satisfy — consistent with proposal.md's explicit
   "keep `cluster.replicas`" decision, and it fails the whole render (no partial CR emitted),
   matching this chart's existing `fail`-on-invalid-combination style used elsewhere in the main
   chart's `values.schema.json`-adjacent validation.

6. **Documentation: a new subchart `README.md`, plus a one-line note in the main chart's
   `values.yaml` next to the existing `stream:` block.** No README exists today for
   `src/groundx/prereqs/kafka-cluster/` (verified: `find ... -iname README*` returned nothing).
   There is also no literal `namespace:` key in `src/groundx/values.yaml` to anchor a comment on
   (it resolves via the `groundx.ns` helper's `| default "eyelevel"`, `_helpers/main.tpl:1`) —
   adding one only to hold a comment would be a values-surface change the ticket does not ask for,
   so the note goes next to `stream:` (`values.yaml:98`), which already carries a commented Mode-1
   (`existing:`) example in the exact same style. Add one stating the namespace-pairing constraint
   from decision 4 — the subchart's `helm install -n <ns>` must equal the main chart's
   `.Values.namespace`, or the `KafkaTopic` and the Kafka bootstrap service land in different
   namespaces and the `stream-cluster-kafka-bootstrap.<ns>.svc` DNS the main chart's summary/queue
   clients depend on breaks. Both the README and the `values.yaml` note mirror into `helm/`.

7. **Subchart version bump: `0.1.1` → `0.2.0`.** Chart.yaml carries no dependency-version
   constraint elsewhere in this repo to match against (`git log --follow` on this Chart.yaml
   shows only its initial `0.1.1` commit — no prior bump precedent to infer a convention from).
   `0.2.0` follows ordinary semver-under-1.0 practice: the minor segment signals a
   breaking/incompatible change (the CR shape a pinned `0.1.1` consumer gets is not the shape a
   `0.2.0` consumer gets) while staying pre-1.0 to reflect this chart has no stability guarantee
   yet. This is the version string `contract.md` names as the producer→consumer touchpoint with
   `groundx-studio-harness`; that repo's own PR (out of scope here) updates its two references and
   is merge-gated on this version actually being published via the manual, maintainer-only
   `src/build.sh` (contract.md `Strategy`). This pipeline does not run `src/build.sh` — publish is
   a human action after this PR merges.

8. **PRODUCER/HYBRID compatibility mechanism — confirmed against contract.md, not
   re-litigated.** contract.md already classifies this touchpoint (`Versioned` strategy + a
   publish-gated merge hold on the consumer PR) and confirms the mechanism exists in code (the
   subchart `Chart.yaml` `version` field is real, and `src/build.sh` is the real, existing publish
   path — verified by reading `src/build.sh`'s `aws s3 cp ... s3://eyelevel-upload/helm/` step
   referenced in this repo's `config.yaml` context). No re-classification is needed: the
   underlying CRD move is `Breaking` at the Kafka-CRD level as contract.md already notes, and the
   version-bump-plus-merge-hold is the real compatibility mechanism, not a fabricated one.

9. **`helm-unittest` new suite location:
   `src/groundx/prereqs/kafka-cluster/tests/cluster_test.yaml`.** This subchart has no `tests/`
   directory today; the main chart's convention (`src/groundx/tests/*_test.yaml` +
   `tests/__snapshot__/*.snap`, `AGENTS.md`) is mirrored one level down inside the subchart so
   `helm unittest src/groundx/prereqs/kafka-cluster` (and the umbrella
   `.build/bin/validate-helm.sh`, which already runs `helm unittest src/groundx` and would need
   this path added — see tasks.md) can discover it the same way.

## Risks / Trade-offs

- **[Risk] A field/customer install already running the old `v1beta2` shape cannot roll forward
  in place** — Strimzi does not serve both `v1beta2` and `v1` from one operator install, and a
  `v1` `Kafka` CR with `replicas`/`storage` removed is a different shape than the CR a `v1beta2`
  operator expects. → **Mitigation:** proposal.md's documented rollback/roll-forward guidance
  (pin the Strimzi operator until ready to upgrade operator + subchart together); no in-repo
  migration script is warranted since this is a template-only change with no persisted state
  (Kafka topic data is unaffected by the CR's API version or namespace field).
- **[Risk] The `fail`-on-guard (decision 5) is a new failure mode for any existing values file
  that happens to set `cluster.replicas` above `nodepool.replicas`** — none of this chart's
  shipped `values/*.yaml` examples do this (both default to `1`), but a customer override could.
  → **Mitigation:** the guard's error message names both keys and the fix (lower
  `cluster.replicas` or raise `nodepool.replicas`); documented in the new subchart README
  (decision 6).
- **[Risk] The live-Strimzi `kind` job adds real CI runtime and a Docker-in-CI dependency** — a
  `kind` cluster plus two `helm install`s plus reconcile-wait is materially slower than the
  existing unit-test job. → **Mitigation:** proposal.md already scopes it to `pull_request` and
  `release` only (not every push), keeping the fast unit-test gate fast; the job fails (not
  skips) when `kind`/Docker is unavailable, so a misconfigured runner cannot silently stop
  gating.
- **[Trade-off] `0.2.0` is a version-number decision made here, not by a human at proposal time**
  — flagged in this design (decision 7) rather than silently assumed; the reviewer sees the
  rationale and can override before this ships.

## Migration Plan

1. Land the chart-template + values + `helm-unittest` changes in `src/groundx/` (this is a
   template-only change — no stateful resource migration).
2. Mirror the same edits into `helm/` (this repo's existing, tool-free manual-sync convention).
3. Re-baseline `src/groundx/tests/__snapshot__/stream_test.yaml.snap` for the `KafkaTopic`
   `apiVersion` change (`helm unittest -u src/groundx`, `AGENTS.md`-documented regen command).
4. Add the live-Strimzi `kind` job to `.github/workflows/` (new file, sibling to
   `helm-tests.yml` — proposal.md keeps it out of the existing fast unit-test job).
5. Bump `src/groundx/prereqs/kafka-cluster/Chart.yaml` to `0.2.0` and mirror to
   `helm/prereqs/kafka-cluster/Chart.yaml`.
6. **Publish is out of pipeline scope** — a human runs the `PRIVILEGED` `src/build.sh` after this
   PR merges (this pipeline never runs it); the `groundx-studio-harness` PR is merge-gated on that
   publish per contract.md.
7. **Rollback:** revert this PR (chart-template-only, no persisted state to reshape) and, for any
   environment mid-rollout, pin the Strimzi operator to the version paired with whichever chart
   version is actually installed (proposal.md's Rollback/Roll-forward section).

## Open Questions

None — the fix direction (v1, field removal, optional versions, `.Release.Namespace` on the
subchart only) is confirmed by Ben Fletcher's review comment and this session's spike (source-of-
truth pack); the mechanism decisions above (guard shape, version bump, doc location, test-suite
location) are resolved in this document rather than left for tasks.md to re-decide.
