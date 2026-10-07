## Why

Increment 1 of this change (archived `2026-09-03-gx-25-...`) moved the
`groundx-strimzi-kafka-cluster` subchart's Kafka CRs to `kafka.strimzi.io/v1` and bumped the
subchart's own `Chart.yaml` from `0.1.1` to `0.2.0`. The overall release this ships in — the main
`groundx` chart, the harness docs, and the other two coordinated PRs — is being cut as `0.2.7`, so
the subchart's `0.2.0` no longer matches the version everything else in the release references.
Separately, Ben's 2026-09-04 review of that release raised two release blockers this
increment closes: (1) the increment-1 proposal explicitly deferred the 0.1.x-install upgrade path
and the air-gapped/Chainguard image bump as out of scope — but the charts are public, so an existing
0.1.x customer install is a real, unowned upgrade risk, not a hypothetical; Ben now requires a
**tested** migration runbook before release. (2) A v1-serving Strimzi image is confirmed to exist in
the Chainguard mirror (`cgr.dev`, 0.50.1/0.50.1, both APIs), which un-blocks the air-gapped path that
increment 1 could not attempt.

## What Changes

- **Version alignment**: bump `src/groundx/prereqs/kafka-cluster/Chart.yaml` `version: 0.2.0` to
  `0.2.7`, mirrored into `helm/prereqs/kafka-cluster/Chart.yaml`, so the chart, the subchart
  README's install example, the harness docs, and the release all read one version. Update the
  README's `helm install ... --version 0.2.0` example to `--version 0.2.7` (both
  `src/groundx/prereqs/kafka-cluster/README.md` and its `helm/` mirror — the two are currently
  byte-identical).
- **Tested 0.1.x -> 0.2.7 migration path (release blocker)**: expand the subchart README's existing
  "Upgrading an existing 0.1.x install" section (added in increment 1, currently a 3-point
  requirements list with no procedure) into the exact, ordered conversion runbook:
  1. Upgrade the Strimzi operator in place to `0.50.1` — the newest dual-serving release (0.49
     through 0.51 all serve **both** `kafka.strimzi.io/v1beta2` and `kafka.strimzi.io/v1`) that
     still supports Apache Kafka `4.0.x`, so it carries the running cluster's pinned Kafka version
     across the hop; `0.51.0` drops Kafka `4.0.x` and cannot. Do not upgrade straight from a
     v1beta2-only operator to a v1-only one.
  2. Run Strimzi's `strimzi-v1-api-conversion` tool plus the CRD upgrade against the existing
     `Kafka`/`KafkaNodePool` custom resources, so the stored CR version becomes `v1` while the
     operator is still the 0.50.1 stepping-stone. **Convert the CRDs in place — never delete and
     recreate them**; deleting a Strimzi CRD deletes the managed `Kafka`/`KafkaNodePool` resources
     Kubernetes tracks under it, which destroys the running cluster's control-plane object (not the
     topic data, but the object Strimzi reconciles against).
  3. Only then `helm upgrade` the subchart release to chart `0.2.7` (the `v1`-only template shape).
  4. Across the whole operator hop, pin `cluster.version`/`cluster.metaVersion` to the Kafka version
     already running (this constraint already exists in the increment-1 README note; this increment
     makes it an explicit numbered step in the procedure rather than an implicit prerequisite).
  5. Keep the `helm upgrade` release namespace equal to the **old** `.Values.namespace` the 0.1.x
     install used — increment 1 moved the subchart's CRs to `.Release.Namespace`; upgrading under a
     different namespace orphans the running cluster rather than upgrading it.
  6. Before upgrading, reconcile `cluster.replicas <= nodepool.replicas` — the subchart's existing
     render-time guard (`{{ fail ... }}` in `templates/cluster.yaml`) rejects the upgrade outright if
     this doesn't already hold, so the runbook calls it out as a pre-check rather than letting the
     upgrade fail mid-procedure.
  - **CI proof, not just docs**: add an automated `kind` upgrade-test job to
    `.github/workflows/kafka-strimzi-kind.yml` (new job, alongside the existing `live-strimzi-kind`
    job, which stays unchanged) that: installs the old Strimzi operator `0.47.0` and the vendored old
    subchart package `helm-releases/groundx-strimzi-kafka-cluster-0.1.1.tgz` (both v1beta2-shaped),
    waits for the Kafka cluster to reach `Ready`, then drives the exact runbook above — the
    conversion tool + CRD upgrade, the operator upgrade to `0.50.1`, and the `helm upgrade` to the
    current (post-increment-1, v1-shaped) chart under `src/groundx/prereqs/kafka-cluster` — and
    asserts the `Kafka` custom resource and every `KafkaTopic` stay `Ready` through the whole
    conversion (not just at the end). This is the empirical proof Ben's ask requires; per the
    workspace's spike-declined-local classification for this external-semantics assumption, the CI
    job itself is the validating artifact, not a separate spike.
- **Air-gapped/Chainguard v1 image**: bump every Strimzi image `tag`/`tagPrefix` in
  `src/groundx/values/chainguard/values.strimzi.operator.yaml` (mirrored into
  `helm/values/chainguard/values.strimzi.operator.yaml`) from `v0.48.0` to the `0.50.1` release
  confirmed to exist in the Chainguard mirror (serves both APIs, so it is also usable as the
  air-gapped operator's own upgrade stepping-stone). Fix
  `src/groundx/values/chainguard/values.strimzi.cluster.yaml` (mirrored into
  `helm/values/chainguard/values.strimzi.cluster.yaml`) `cluster.version: 4.1.0` override, to match the main v1 chart's greenfield behavior. 0.50.1
  supports Apache Kafka 4.0.0 through 4.1.1, so 4.1.0 is itself supported; the override is dropped
  for consistency with the greenfield default, not because the version is unsupported. The
  greenfield (non-air-gapped) subchart leaves `cluster.version`/`cluster.metaVersion` **unset** so
  Strimzi picks its own supported default; this proposal's chosen default is to leave the
  air-gapped/Chainguard values **unset** as well rather than pin an explicit version, on the
  reasoning that there is no stated requirement for the air-gapped path to behave differently from
  the already-shipped greenfield default, and an explicit pin would need its own re-justification
  every time Strimzi's supported-version floor moves. This is a reversible, in-scope default; design
  will confirm the exact Chainguard image tag string (e.g. whether the registry publishes `0.50.1` or
  `v0.50.1` — the current values file uses a `v`-prefixed tag) against the live `cgr.dev` mirror
  before implementation.

Out of scope for this increment: the harness docs update (subchart version reference,
`groundx-studio-harness`) is a separate repo's PR, coordinated via the existing FINALIZED contract
(`contract.md`) and merge-held on this chart's publish, same as increment 1. No other subsystem,
service, or CRD is touched.

**Blast radius:** Mode 2 (bundled/in-cluster Kafka) installs only, same as increment 1 — Mode 1
(external Kafka) and Mode 3 (SQS) render no Strimzi resources and are unaffected. Environments:
- **New/greenfield installs** (dev/staging/prod, any cluster standing up Mode 2 for the first time):
  only the version-string bump changes anything observable; no behavior change beyond the chart
  version and README example already shipped in increment 1.
- **Existing 0.1.x installs** (a real, public-chart risk per Ben's ask, not a hypothetical): this is
  the increment that makes the upgrade actually documented and CI-tested; before this increment such
  an install had no supported upgrade path at all in this repo. The runbook is a manual, human-run
  procedure (operator upgrade, conversion tool, `helm upgrade`) — this pipeline does not run it.
- **Air-gapped/Chainguard Mode 2 installs**: the operator/cluster image-tag and version-value fixes
  only take effect for `imageType: chainguard` deployments; standard-image deployments are
  unaffected.

**Rollback:** chart-template-version and values-file changes only — no data-plane migration ships
in this increment. Reverting to chart `0.2.0`/operator `v0.48.0`/`cluster.version: 4.1.0` restores
the prior (already-broken-for-air-gapped, already-undocumented-for-upgrade) state; no persisted Kafka
topic data is reshaped by any change in this increment. The migration runbook itself is additive
documentation plus a new CI job — it does not change the subchart's rendered output for a fresh
install.

**Roll-forward:** a field/customer install already running 0.1.x should follow the new runbook in
order (operator to 0.50.1 first, convert, then `helm upgrade` to 0.2.7) rather than jumping straight
to an unpinned latest operator, which increment 1's original (pre-runbook) guidance would have left
ambiguous for an existing install.

No open design questions remain for this increment — the version bump, the runbook's step order and
CRD-convert-never-delete constraint, and the Chainguard image/version fixes are all fixed by Ben's
2026-09-04 comment and the verified external Strimzi/Chainguard release facts recorded in
`source-of-truth.md`. The one implementation-time confirmation noted above (exact Chainguard tag
string format) is a design/apply-time registry read, not a design ambiguity requiring
`superpowers:brainstorming`.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `strimzi-kafka-v1-compat`: adds requirements for (1) the subchart's published version aligning
  across `Chart.yaml`, the README install example, and the harness contract reference; (2) a tested,
  documented, CI-proven 0.1.x -> current conversion procedure (operator stepping-stone version, CRD
  conversion tool, never deleting CRDs, namespace/version-pin preservation, and a `kind` CI leg that
  proves the Kafka cluster and its KafkaTopics stay `Ready` through the conversion); (3) the
  air-gapped/Chainguard values carrying a supported Strimzi operator image and Kafka cluster version
  consistent with the main v1-only chart.

## Impact

- **Code:** `src/groundx/prereqs/kafka-cluster/Chart.yaml`,
  `src/groundx/prereqs/kafka-cluster/README.md`,
  `src/groundx/values/chainguard/values.strimzi.operator.yaml`,
  `src/groundx/values/chainguard/values.strimzi.cluster.yaml` — each mirrored into the matching
  `helm/` path. No template (`templates/cluster.yaml`, `templates/nodepool.yaml`) changes in this
  increment; the v1 CR shape is already increment 1's shipped state.
- **CI:** a new upgrade-test job in `.github/workflows/kafka-strimzi-kind.yml`, additive alongside
  the existing greenfield-install job and the existing v1beta2-reject probe (both unchanged),
  exercising the vendored `helm-releases/groundx-strimzi-kafka-cluster-0.1.1.tgz` package already
  present in this repo.
- **Docs:** the subchart README's migration section grows from a requirements list into a numbered
  procedure. No other repo doc changes ship from this PR — the harness doc/version-reference update
  is the separate, contract-coordinated consumer PR (unchanged from increment 1's arrangement).
- **Dependencies:** none in-repo; external dependency is the specific Strimzi operator releases named
  in the runbook (0.47.0 old / 0.50.1 stepping-stone) and the Chainguard-mirrored Strimzi image
  version, both already verified to exist (see `source-of-truth.md`).
- **No API/schema contract change** to `src/groundx/values.schema.json` — the Chainguard values files
  touched here are plain values overrides, not schema-governed keys.
