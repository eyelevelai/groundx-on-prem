# Anthropic workflow engine service implementation plan

## Global constraints

- Base the plan and implementation on current pushed `origin/0.2.7` in an isolated
  worktree. Carry only this OpenSpec change and its eventual implementation; do not
  include `origin/main`-only commits.

## 1. Lock current failure with render tests

- [x] 1.1 Add failing summary tests showing an explicit service can inherit the wrong
  in-cluster endpoint or credential.
- [x] 1.2 Add a failing render test proving the schema-supported
  `engines.<name>.service` field is currently ignored, plus one custom non-default
  engine case proving legacy `serviceType` currently wins when both values disagree.
- [x] 1.3 Add failing extraction-agent tests for explicit endpoint, model, kwargs,
  reasoning, service value, and credential pass-through.
- [x] 1.4 Add cases proving a missing provider key does not fail Helm rendering or
  inherit the GroundX admin key.
- [x] 1.5 Add a regression case proving an engine ID without a service keeps the local
  summary API and inference workloads.

## 2. Replace provider allowlists with explicit configuration

- [x] 2.1 Use explicit service presence, rather than a provider-name allowlist, to
  choose between supplied configuration and local defaults.
- [x] 2.2 Render the existing `engines.<name>.service` schema field, retaining
  `serviceType` only as a compatibility fallback. Prove documented `service` wins when
  a custom engine supplies both values; add no separate `serviceType`-only fixture.
- [x] 2.3 Reuse existing URL, endpoint, engine, model, and credential fields. Add no
  values or schema properties.
- [x] 2.4 Render any explicitly supplied key and never substitute `admin.apiKey` for an
  explicit service. Do not require provider authentication in Helm.
- [x] 2.5 Render any explicit extraction service into `AgentSettings`, including custom
  hosted and self-hosted values.
- [x] 2.6 Preserve omitted-service defaults and Bedrock's S3 infrastructure check.
- [x] 2.7 Make extraction inherit the resolved default summary engine when no
  extraction service is selected.
- [x] 2.8 Keep explicit extraction settings authoritative and deploy local model
  workloads when an explicit local extraction engine needs them.
- [x] 2.9 Resolve configured and generated engines once, then use that resolved map for
  summary rendering, local workload selection, and inherited extraction settings.
- [x] 2.10 Resolve the effective extraction engine once, then make extraction field
  helpers and local workload selection read that resolved map.
- [x] 2.11 Use the chart's settings, existing, and create helper conventions; share
  the engine format and local-pod decision, and validate engines in their builder.
- [x] 2.12 Remove the extraction file settings forwarding layer and share file URL,
  TLS, and port parsing. Preserve account inheritance, explicit empty credentials,
  upload configuration, and local storage wait addresses without adding schema fields.

## 3. Synchronize generated and published surfaces

- [x] 3.1 Regenerate affected Helm unit snapshots. Do not edit snapshots manually.
- [x] 3.2 Copy the matching changed source templates and contract files into the
  published `helm` mirror and compare both surfaces.
- [x] 3.3 Update concise values guidance for the existing fields without adding
  credentials or a second configuration shape. Add a release note that per-engine
  `service` now takes effect and wins over legacy `serviceType` when both are present.
- [x] 3.4 Document and test Anthropic URL values as API roots ending at `/v1`; do not
  configure the `/v1/messages` operation path because each native runtime appends it.

## 4. Validate and release safely

- [x] 4.1 Run `.build/bin/validate-helm.sh`, `helm template src/groundx -f
  src/groundx/values/minikube/values.yaml`, strict OpenSpec validation, and `git diff
  --check`.
- [x] 4.2 Record the Fern and Cashbot prerequisite versions and the immutable application
  images that support native Anthropic.
  Source prerequisites, current deployments, and the extraction-image candidate are
  recorded in `release-verification.md`, including the matching summary-client image.
  Candidate images are not currently deployed. The extraction candidate was briefly
  deployed at revision 349, then reverted at revision 350. Provider canary scope is
  recorded separately below.
- [x] 4.3 Canary one text summary and one multimodal extraction-agent request with no
  credential values in evidence.
  Both passed on 2026-09-08 with the reloaded bash-profile credential. Text used the
  Cashbot production client from the candidate source; image extraction used the
  built container and inherited chart configuration. Results and limits are recorded
  in `release-verification.md`.
- [x] 4.4 Complete the opted-in production provider validation and retain the
  `service`/`serviceType` precedence precaution in both chart READMEs. The inspected
  `gxprod` release has no conflicting custom-engine values. Inventory and rollout
  checks for other environments belong to their future deployments, not this
  implementation plan; those deployments have not been performed or certified.

### Production canary

### Merged metadata guard and source-text release

- [x] Build Cashbot `2137e1a2603abeb405a7c52223cdaf8806729749` preprocessing Lambda
  and Arcadia `a9fef08328fa0809e8785aa28dbe3b7988663c5a` extract image through
  their owning GitHub Actions workflows. Verify both build source SHAs and digests.
- [x] Snapshot the production Lambda, SQS mapping, Helm revision, and four extract
  workloads. Deploy only those images in account `903713046261`, `us-west-2`,
  context `gxprod`, namespace `eyelevel`. Preserve the existing chart, configuration,
  credentials, and customer workflows. Verify the rendered changes contain only the
  four extraction image replacements. Preserve worker graceful termination.
- [x] Verify runtime identity and readiness. Restore the prior Lambda image through
  the release script and Helm revision 350 if deployment verification fails.
- [x] Resubmit the existing synthetic text and image sources to buckets 33447 and
  33448 with unchanged workflows. Save new evidence in `source-text-retest/` under
  the existing private runtime root. Verify metadata, original text in image-free QA,
  unchanged image evidence, final callback, and authoritative `get_extract` output.
  Distinguish no-conflict reconciliation from a reconciliation provider call.
- [x] Record build/deployment provenance and canary results. Retain prior evidence
  and isolated resources pending cleanup approval. No chart release or customer
  default provider assignment is included.
  Both canaries pass. Current deployment and evidence are recorded in
  `source-text-release.md`. Reconciliation used the no-conflict path; QA made one
  Anthropic call per document, using original text for TXT and one image for PNG.

### Dispatch Lambda compatibility and retest

- [x] Identify the failed boundary. Production `PreProcessTrainFile` source
  `711ec939` converts unknown `anthropic` to `hosted`, changes the workflow artifact
  hash, and sends extraction without the saved reassembly metadata. Reproduction
  against both saved workflow records confirms current Anthropic-aware source
  preserves the hash and finds all three artifacts.
- [x] Build only `pre-process-lambda` from pushed Cashbot `d8c8e69` through GitHub
  Actions. Retain the prior immutable Lambda digest and event-source settings.
- [x] Deploy the built digest through `.build/bin/release.sh -prod --image-uri`.
  Verify successful update, unchanged runtime configuration and SQS mapping, and
  correct source provenance. Roll back through the same script if deployment
  verification fails.
- [x] Rerun the two synthetic canaries with unchanged schema and provider settings.
  Preserve previous evidence. Verify metadata in dispatch and ingress, successful
  reconciliation and QA, and authoritative final extraction values. Leave customer
  workflows, Kubernetes images, defaults, and credentials unchanged.
  Both dispatch and ingress packets now contain metadata. Image extraction, QA,
  save, and final retrieval pass. Reconciliation passes without a model call because
  there are no conflicts. Text extraction and reconciliation pass, but text QA stops
  before its model call because the TXT source has no derived page images. This
  remaining limit is recorded in `release-verification.md`; it is not a complete
  text-workflow pass.

### Original production canary

- Target: `gxprod`, namespace `eyelevel`, release `groundx`.
- Use the existing deployed services. An explicitly configured workflow engine
  already supports native Anthropic; the inherited-default image fix is not needed
  for this test. Do not change deployment images, chart values, or customer defaults.
- Image-only release revision 349 was unnecessary for this workflow test. Rollback
  completed at revision 350. The original images are ready, and the deployed values
  and manifest exactly match revision 348.
- Validate one synthetic text-summary job and one synthetic image-extraction job
  through isolated production resources using the existing Anthropic credential.
  Verify final output and provider/stage evidence, including reconciliation and QA.
  Both Cashbot provider calls returned correct values. Both jobs failed before
  reconciliation because the dispatched task lacked required reassembly metadata.
  Retain the exact-ID evidence; final extraction and reconcile/QA validation remain
  incomplete. The candidate extraction image does not change that metadata loader.
- Owner: release coordinator. Private runtime root:
  `openspec/work/add-anthropic-workflow-engine-service/prod-20260908/`.
  Retain pending verification until 2026-09-15; delete settled raw runtime evidence
  after recording sanitized results. Private Helm rollback copies were removed
  after confirming revision 350 matches revision 348; Helm retains the release history.
