Builds on `proposal.md`'s three release-blocker items for increment 2 (version alignment, a
tested migration runbook, and the Chainguard air-gapped image/version fix) — this document covers
the technical decisions the proposal left open.

## Goals / Non-Goals

**Goals:**
- Make every reader of the subchart's version (its own `Chart.yaml`, its README install example,
  and the harness's `contract.md`-tracked reference) see the same `0.2.7` string.
- Give an existing 0.1.x/`v1beta2` customer install a documented, ordered, CI-proven path to the
  current `v1`-shaped chart that never deletes the running cluster's control-plane object.
- Make the air-gapped/Chainguard Mode-2 install path use a Strimzi image and Kafka cluster version
  that a current Strimzi release actually supports, matching the already-shipped greenfield
  default.

**Non-Goals:**
- Any change to the `Kafka`/`KafkaNodePool`/`KafkaTopic` template shape — increment 1 already
  shipped the `v1` CR move; this increment touches `Chart.yaml`, `README.md`, CI, and two
  Chainguard values files only.
- Running the migration runbook against any real cluster, or publishing the bumped chart version
  — the runbook is a documented, human-run procedure and the version is published by a human
  running the `PRIVILEGED`, maintainer-only `src/build.sh` after this PR merges (`contract.md`).
- The `groundx-studio-harness` doc-reference update — a separate repo's PR, merge-held on the
  `0.2.7` publish (`contract.md`, unchanged from increment 1's arrangement).

## Decisions

**Invariant (gate-class trigger — the new kind upgrade-test CI job):** the migration runbook the
new CI job proves is correct only if the running `Kafka` custom resource and every `KafkaTopic`
custom resource **stay `Ready` at every point during the conversion**, not merely before it starts
and after it ends — a runbook that transiently deletes and recreates a CRD (rather than converting
it in place) can produce a cluster that reports `Ready` again at the end while having destroyed and
rebuilt the control-plane object in between, which is exactly the loss the "convert, never delete"
constraint exists to prevent. The two spec.md scenarios under "an automated kind CI job proves the
v1beta2 -> v1 migration runbook keeps the running cluster and its topics Ready throughout" (catches
a delete-and-recreate; must not block the documented in-order runbook) encode this.

1. **The new CI job polls `Ready` through the conversion, not only at the end.** Concretely: the
   job's assertion steps run `kubectl wait ... --for=condition=Ready` immediately after the
   pre-upgrade install (baseline), then again immediately after the CRD-conversion step, then again
   after the `helm upgrade` to `0.2.7` — three checkpoints, not one. A single end-of-job `Ready`
   check would pass on a delete-and-recreate migration (the object exists and is `Ready` again by
   the time the job checks it), which is precisely the counterexample the invariant above names.

2. **CRD conversion runs Strimzi's own `strimzi-v1-api-conversion` tool plus the CRD upgrade —
   never a manual `kubectl delete` / `kubectl apply` of the CRD.** Strimzi ships this tool
   specifically to convert stored custom-resource versions in place; a `delete`+`apply` of the CRD
   deletes every `Kafka`/`KafkaNodePool` object Kubernetes tracks under it, which is the risk the
   runbook and the CI job both exist to catch. The CI job step for this stage invokes the tool by
   name so the workflow file itself is evidence the documented procedure is what actually runs, not
   a paraphrase.

3. **The stepping-stone operator version is `0.51.0`, pinned exactly (not "any 0.49.x-0.51.x
   release").** `contract.md`'s corrected fact and `source-of-truth.md` establish 0.49.0-0.51.x as
   the window where Strimzi serves both `v1beta2` and `v1`; `0.51.0` is the newest release in that
   window and is the version this design pins everywhere (README runbook, CI job, and — per
   decision 6 below — the Chainguard operator image), so the runbook, the CI proof, and the
   air-gapped image path all name the identical stepping-stone rather than three independently
   "close enough" versions that could drift apart.

4. **Old operator/chart versions used by the CI job's pre-upgrade baseline are the already-vendored
   ones — no new fixture.** The job installs Strimzi operator `0.47.0` (the version the original
   ticket's repro used, `source-of-truth.md`) and the subchart package already vendored at
   `helm-releases/groundx-strimzi-kafka-cluster-0.1.1.tgz` (verified present in this repo). No new
   binary or chart package needs to be committed for this increment.

5. **Version-string alignment is a grep-checkable identity, not a template render.** The three
   locations (`Chart.yaml` x2, `README.md` x2) are files sdd-builder writes directly in the apply
   phase — mechanical, not template-derived — so their acceptance check is direct file content
   comparison (see tasks.md), not a `helm template` render.

6. **Chainguard operator image tag: `v0.51.0`, keeping the existing `v`-prefix, replacing
   `v0.48.0`.** The values file's existing convention pins every `tag`/`tagPrefix` with a
   `v`-prefix (`v0.48.0`); the apply-phase task instruction states both `0.51.0` and `v0.51.0` are
   published Chainguard mirror tags for this release, so this design keeps the file's established
   `v`-prefixed format rather than introducing a one-off unprefixed exception. (Supersedes this
   decision's original text, which pinned the bare `0.51.0` string on an unverified assumption — see
   the Risks entry below.) **This builder still could not independently read the live `cgr.dev`
   registry in this session** (no `chainguard-pull-secret` credential); the tag-existence fact is
   relayed from the instructing orchestrator, not independently re-verified against the registry by
   this builder.
7. **`cluster.version` becomes fully absent from the Chainguard cluster values file, not an empty
   string.** The subchart's own `values.yaml` already defaults `cluster.version: ""` (unset); the
   Chainguard cluster values file's only content is the `node:` key plus the `cluster.version:
   4.1.0` override being removed — deleting the override (rather than adding an explicit `""`)
   makes the greenfield default apply through normal Helm values-layering, with no redundant
   re-statement of the subchart's own default.
8. **No template logic changes in this increment, so no new `helm-unittest` suite.** Every touched
   file in this increment (`Chart.yaml`, `README.md`, the two Chainguard values files, the CI
   workflow) is a plain string/YAML edit, not a template (`.tpl`/template-directory) change — the
   subchart's existing `tests/cluster_test.yaml`/`tests/nodepool_test.yaml` suite (increment 1)
   already covers the rendered-CR shape and is untouched. tasks.md's checks are grep/YAML-parse
   commands, matching this repo's `AGENTS.md` convention that `helm-unittest` guards *template*
   changes specifically.
9. **PRODUCER compatibility mechanism — already confirmed in `contract.md`, not re-litigated.**
   `contract.md`'s touchpoint entry already classifies the subchart-version bump as `Versioned` +
   a publish-gated merge hold on the consumer PR, and already confirms the mechanism is real (the
   `Chart.yaml` `version` field, and `src/build.sh`'s `aws s3 cp ... s3://eyelevel-upload/helm/`
   publish path). This increment only changes the version string the mechanism carries (`0.2.0` ->
   `0.2.7`); no re-classification is needed. Producer contract shapes and the full rollout strategy
   are confirmed in `contract.md` — see that file, not a restatement here.
10. **No ADR.** None of the three items in this increment is architecturally significant or hard to
    reverse: a version-string bump, an expanded (but non-behavioral) README section, and two values
    files being brought in line with an already-shipped default. Reverting any of the three restores
    the prior state with no persisted-state implication (proposal.md's Rollback section).

## Risks / Trade-offs

- **[Risk, narrowed] The Chainguard operator image tag string.** Decision 6 originally pinned the
  bare `0.51.0` string (no `v`-prefix) on an unverified assumption. At apply time the instructing
  orchestrator stated both `0.51.0` and `v0.51.0` are published tags for the target release, so the
  values file keeps its established `v`-prefixed convention (`v0.51.0`) rather than introducing a
  one-off unprefixed exception — narrower risk than before (a wrong prefix, not a wrong version).
  This builder still has no `chainguard-pull-secret` credential and did not independently read the
  live `cgr.dev` registry in this session. **Mitigation (unchanged):** the literal is pinned
  consistently everywhere it appears (values file, this design doc, the README runbook, and the CI
  job), so a wrong prefix is a single, easy, everywhere-consistent fix; a human with registry
  access should still spot-check `crane ls cgr.dev/eyelevel.ai/strimzi-kafka-operator` before this
  PR merges.
- **[Risk] The new kind upgrade-test CI job adds real runtime to an already-Docker-dependent
  workflow** (a second `kind`-cluster job, on top of the existing `live-strimzi-kind` job, each
  performing at least one full Strimzi operator install and a multi-step upgrade) — total workflow
  runtime for `kafka-strimzi-kind.yml` roughly doubles. → **Mitigation:** proposal.md already scopes
  the whole workflow to `pull_request`/`release` only (not every push); the two jobs are
  independent and run in parallel (no `needs:` between them), so wall-clock impact is bounded by
  the slower of the two, not their sum.
- **[Trade-off] The runbook is documentation + a CI proof, not an automated migration tool** — a
  real 0.1.x customer still runs the operator upgrade, the conversion tool, and `helm upgrade`
  themselves, by hand, in their own cluster. → Accepted: this pipeline never runs a migration
  against a real customer cluster (AGENTS.md — no destructive/deploy action without human
  authorization); the CI job proves the *procedure* is safe, it does not perform the procedure for
  the customer.

## Migration Plan

1. Bump `src/groundx/prereqs/kafka-cluster/Chart.yaml` `version` to `0.2.7`; mirror to
   `helm/prereqs/kafka-cluster/Chart.yaml`.
2. Update the README `--version` example (`src/groundx/prereqs/kafka-cluster/README.md`, mirrored
   to `helm/`) to `0.2.7`, and expand the "Upgrading an existing 0.1.x install" section into the
   ordered runbook (decisions 1-5 above), in both copies.
3. Add the new upgrade-test job to `.github/workflows/kafka-strimzi-kind.yml`, alongside the
   existing `live-strimzi-kind` job (unchanged).
4. Bump `src/groundx/values/chainguard/values.strimzi.operator.yaml` (mirrored to `helm/`) every
   `tag`/`tagPrefix` from `v0.48.0` to `0.51.0`.
5. Remove the `cluster.version: 4.1.0` override from
   `src/groundx/values/chainguard/values.strimzi.cluster.yaml` (mirrored to `helm/`).
6. **Publish is out of pipeline scope** — a human runs the `PRIVILEGED` `src/build.sh` after this
   PR merges; the `groundx-studio-harness` PR stays merge-held on that publish (`contract.md`).
7. **Rollback:** revert this PR (version-string, docs, values-file, and CI-only — no persisted
   Kafka topic data or rendered-CR shape changes); an in-flight 0.1.x customer who has not yet
   started the runbook is unaffected by the revert.

## Open Questions

None for this increment's authored content. The one implementation-time confirmation flagged in
decision 6 / the Risks section (the exact Chainguard tag string) is a live-registry spot-check for
a human with credentials, not a design ambiguity requiring `superpowers:brainstorming` — the
literal this design pins is sourced from `proposal.md`'s already-confirmed fact and applied
consistently.
