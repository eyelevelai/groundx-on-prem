## 1. Version alignment: Chart.yaml + README install example (thin vertical slice — chart version, its mirror, and the docs example a customer copies all read 0.2.7, independently shippable)

- [x] 1.1 Bump `version` in `src/groundx/prereqs/kafka-cluster/Chart.yaml` from `0.2.0` to `0.2.7`; mirror the identical bump into `helm/prereqs/kafka-cluster/Chart.yaml`
  check: grep -qx 'version: 0.2.7' src/groundx/prereqs/kafka-cluster/Chart.yaml && grep -qx 'version: 0.2.7' helm/prereqs/kafka-cluster/Chart.yaml
- [x] 1.2 Update the README's `helm install ... --version 0.2.0` example to `--version 0.2.7`, in both `src/groundx/prereqs/kafka-cluster/README.md` and its `helm/` mirror
  check: grep -q -- '--version 0.2.7' src/groundx/prereqs/kafka-cluster/README.md && grep -q -- '--version 0.2.7' helm/prereqs/kafka-cluster/README.md && ! grep -q -- '--version 0.2.0' src/groundx/prereqs/kafka-cluster/README.md && ! grep -q -- '--version 0.2.0' helm/prereqs/kafka-cluster/README.md

## 2. Tested 0.1.x -> 0.2.7 migration runbook (README expansion, src + helm mirror; design.md decisions 1-5)

- [x] 2.1 Expand the "Upgrading an existing 0.1.x install" section of `src/groundx/prereqs/kafka-cluster/README.md` (and its `helm/` mirror) into the exact ordered runbook: (1) upgrade the Strimzi operator in place to `0.50.1` as the dual-serving stepping-stone; (2) apply the operator release's CRD bundle so every Strimzi CRD serves both `v1beta2` and `v1` (helm upgrade does not upgrade CRDs; the conversion tool refuses to run until they do); (3) run Strimzi's `strimzi-v1-api-conversion` tool plus the CRD upgrade against the existing `Kafka`/`KafkaNodePool` resources, converting the stored CRD version to `v1` in place — state explicitly that CRDs are converted, never deleted and recreated; (4) only then `helm upgrade` the release to chart `0.2.7`; (5) pin `cluster.version`/`cluster.metaVersion` to the already-running Kafka version across the whole hop; (6) keep the upgrade's release namespace equal to the old install's `.Values.namespace`; (7) pre-check `cluster.replicas <= nodepool.replicas` before upgrading
  check: grep -q '0.50.1' src/groundx/prereqs/kafka-cluster/README.md && grep -q 'strimzi-v1-api-conversion' src/groundx/prereqs/kafka-cluster/README.md && grep -qi 'never delete' src/groundx/prereqs/kafka-cluster/README.md && grep -q '0.50.1' helm/prereqs/kafka-cluster/README.md && grep -q 'strimzi-v1-api-conversion' helm/prereqs/kafka-cluster/README.md && grep -qi 'never delete' helm/prereqs/kafka-cluster/README.md
- [x] 2.2 (codex r5) Handle a 0.1.x install whose Helm release namespace differs from the CR namespace, and order the preconditions before the chart upgrade: the runbook detects the release-vs-CR namespace split (release from `helm list`, CRs from `kubectl get kafka -A`) and stops on a mismatch, and all three preconditions (namespace match, `cluster.replicas <= nodepool.replicas`, version pin) precede the `helm upgrade` step. (src + helm mirror.)
  check: for f in src/groundx/prereqs/kafka-cluster/README.md helm/prereqs/kafka-cluster/README.md; do grep -q "helm list -A -f" "$f" && grep -q "Preconditions: confirm all three BEFORE step 1" "$f" && [ "$(grep -n "Preconditions: confirm all three BEFORE step 1" "$f" | head -1 | cut -d: -f1)" -lt "$(grep -n "Only then run .helm upgrade. to chart .0.2.7." "$f" | head -1 | cut -d: -f1)" ] || exit 1; done

## 3. Automated kind CI proof of the migration runbook (design.md decisions 1-4; additive alongside the existing, unchanged `live-strimzi-kind` job)

- [x] 3.1 Add a new job to `.github/workflows/kafka-strimzi-kind.yml` that installs Strimzi operator `0.47.0` and the vendored `helm-releases/groundx-strimzi-kafka-cluster-0.1.1.tgz` package (both `v1beta2`-shaped), then waits for the `Kafka` custom resource and all five `KafkaTopic` custom resources to reach `Ready` (the pre-upgrade baseline checkpoint)
  check: grep -q '0.47.0' .github/workflows/kafka-strimzi-kind.yml && grep -q 'groundx-strimzi-kafka-cluster-0.1.1.tgz' .github/workflows/kafka-strimzi-kind.yml
- [x] 3.2 In the same job, first upgrade the operator in place to `0.50.1` (the dual-serving stepping-stone), then run the conversion tool + CRD upgrade (never a manual delete/recreate of the CRD) against the running resources and wait for `Ready` again (second checkpoint), then `helm upgrade` the subchart release to the current `v1`-shaped chart under `src/groundx/prereqs/kafka-cluster`, then wait for `Ready` a third time (final checkpoint) for the `Kafka` custom resource and all five `KafkaTopic` custom resources. The operator upgrade precedes the conversion, matching the README runbook and the actual CI job order.
  check: grep -q 'strimzi-v1-api-conversion' .github/workflows/kafka-strimzi-kind.yml && grep -q '0.50.1' .github/workflows/kafka-strimzi-kind.yml
- [x] 3.3 Keep the updated workflow file valid YAML (guards the known unquoted-colon break in a step name or value; see this repo's prior fix for this exact failure mode on this file). Verified as part of implementing 3.1/3.2 (author the new job, then parse the file before committing).
  check: n/a — regression guard, not a feature-proving check. The workflow already parses on the unchanged tree (the increment-1 em-dash break is fixed), so a standalone parse check cannot fail as a RED baseline. YAML validity is enforced by the CI job's own run (a malformed workflow fails to start) and re-checked at implement time via the .venv python parse before commit.

## 4. Air-gapped/Chainguard Strimzi values match a currently-supported release (design.md decisions 6-7)

- [x] 4.1 Bump every Strimzi image `tag`/`tagPrefix` in `src/groundx/values/chainguard/values.strimzi.operator.yaml` from `v0.48.0` to `v0.50.1` (keeping the file's established `v`-prefix convention; the tag value is relayed from the plan, not verified against the private `cgr.dev/eyelevel.ai` registry (no pull-secret in the build environment); a human must run `crane ls cgr.dev/eyelevel.ai/strimzi-kafka-operator` to confirm `v0.50.1` before the air-gapped publish); mirror the identical edit into `helm/values/chainguard/values.strimzi.operator.yaml`
  check: grep -q '0.50.1' src/groundx/values/chainguard/values.strimzi.operator.yaml && ! grep -q 'v0.48.0' src/groundx/values/chainguard/values.strimzi.operator.yaml && grep -q '0.50.1' helm/values/chainguard/values.strimzi.operator.yaml && ! grep -q 'v0.48.0' helm/values/chainguard/values.strimzi.operator.yaml
- [x] 4.2 Remove the `cluster.version: 4.1.0` override from `src/groundx/values/chainguard/values.strimzi.cluster.yaml`, leaving `cluster.version` unset so the subchart's own greenfield default (`""`) applies; mirror the identical removal into `helm/values/chainguard/values.strimzi.cluster.yaml`
  check: ! grep -q '4.1.0' src/groundx/values/chainguard/values.strimzi.cluster.yaml && ! grep -q 'version:' src/groundx/values/chainguard/values.strimzi.cluster.yaml && ! grep -q '4.1.0' helm/values/chainguard/values.strimzi.cluster.yaml && ! grep -q 'version:' helm/values/chainguard/values.strimzi.cluster.yaml

---

Cross-repo coordination (not this service's tasks — see the workspace's
`openspec/changes/gx-25-groundx-strimzi-kafka-cluster-mode-2-bundled-kafka-install/` for the
`groundx-studio-harness` doc-reference update from `0.2.0`/`0.1.1` to `0.2.7` and its
publish-gated merge hold): the version bumped in task 1.1 is consumed by
`groundx-studio-harness`'s two chart-version references; that repo's own PR does not merge until
this chart's `0.2.7` is actually published to `registry.groundx.ai/helm` via the manual,
maintainer-only, PRIVILEGED `src/build.sh` — this pipeline never runs `src/build.sh`. The
Chainguard tag string (design.md decision 6 / Risks): the instructing orchestrator stated both
`0.50.1` and `v0.50.1` are published tags for the target release, so the values files keep the
`v`-prefixed convention (`v0.50.1`); this builder had no `chainguard-pull-secret` credential and
could not independently read the live `cgr.dev` registry — a human with registry access should
still spot-check the tag before this PR merges.
