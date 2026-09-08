# Anthropic release verification

Status as of 2026-09-08 12:20 UTC: the merged metadata guard and source-text fixes
are deployed. Both synthetic text and image workflows pass through QA, callback,
and authoritative final retrieval. See [source-text-release.md](source-text-release.md)
for current images, resource IDs, and boundary evidence. The sections below retain
the earlier deployment and failed-canary history. No customer defaults or credentials
were changed.

## Source prerequisites

| Surface | Verified source |
| --- | --- |
| Chart | `cd93229043b8a4cc0fb27d8b9b645e854e7c7ac6`, current `origin/0.2.7`, includes PRs 82 and 83 |
| Fern native service enum | `25e450cbb6c9534a45ad874e5cb9cbe1e2b7d321`, retained in current `origin/main` at `8927874e5cbd152cfa49987906d920e437bebe23` |
| Cashbot runtime prerequisite | `ff72d2d0c027f35fbccbfb9cec24f9f04a457491` |
| Cashbot contract mirrors | `972defa3937a0cc00b7e06107f0339950fbf61b6`, retained in current `origin/master` at `d8c8e69b565c81e9c943cff65154afc5458b5960` |
| Internal Arcadia | `1ebb14967c9ccf6f8dc113d58a358bc23dac6fdb`, current `origin/main`, includes configured-provider default preservation |

Internal Arcadia's current main passed its container-import smoke and Python test
matrix in [CI run 34175126227](https://github.com/eyelevelai/internal-arcadia-agents/actions/runs/34175126227).

## Runtime inventory before the source-text release

- Both hosted summary servers expose healthy endpoints. Their running binaries embed
  clean commit `589d4c9fddbf2b0bb066b8cdf6bab9e80822887f`, which contains the Cashbot
  native-provider prerequisite. The native adapter bytes match current master.
- Kubernetes context `gxprod`, namespace `eyelevel`, Helm release `groundx`, revision
  `350` (restored from `348`): all four extraction workloads use
  `public.ecr.aws/c9r4x6y5/eyelevel/extract@sha256:2224f3a650514596d27279de7373229b9b8f7e6b7ad9be67c291b1952bf58a8f`.
  This is `pr164-dbccfa8-adp-v45`, built before the configured-provider default fix.
- The deployed extraction image contains GroundX `4.0.3` and Pydantic AI `2.36.0`.
- The inspected Helm values have no custom `engines` entries. Extraction explicitly
  selects `openai`. There is no configured per-engine service-key conflict in this
  release. This is not an inventory of every customer deployment.
- The chart still defaults application images to `0.2.7`. Its published
  `eyelevel/summary-client:0.2.7` digest is
  `sha256:15c3ebf6b186edf751583db1cd8b28058fca4255d13fcd8bd473323ad831689f`, published
  2026-07-29. Native-provider support in that container has not been verified.
  Hosted summary-server support does not certify the chart's summary-client image.
  The new summary-client candidate below supplies the verified native-capable source;
  no default image tag or release assignment has been changed.

## Extraction image candidate

[Build 34177031750](https://github.com/eyelevelai/internal-arcadia-agents/actions/runs/34177031750)
uses commit `1ebb14967c9ccf6f8dc113d58a358bc23dac6fdb` and tag
`anthropic-canary-1ebb149`. The first AMD64 push was rate-limited after the image
built; its failed job was retried without changing source.

Both architectures and the multi-architecture manifest passed on retry. The final
immutable image is
`public.ecr.aws/c9r4x6y5/eyelevel/extract@sha256:b7dac18036eb57861da2611882c2ae74934ce89baa5b5c51d3fb9e057e51670c`.

The ARM64 image is
`public.ecr.aws/c9r4x6y5/eyelevel/extract@sha256:4b26a5118426a342f833b0d1574c88d17f4ed2e31a2195d2c8dc6f8ff9e12769`.
Its embedded `BUILD_COMMIT` matches the selected source. With networking disabled,
the real `AgentSettings` constructor and `provider_config_for_engine` accepted the
chart-rendered inherited Anthropic configuration. The authored
`parallel_tool_calls: false` remained false, and an explicit workflow true overrode
it. GroundX is `4.0.3`; Pydantic AI is `2.36.0`.

## Summary-client image candidate

[Build 34177560418](https://github.com/EyeLevel-ai/cashbot-go/actions/runs/34177560418)
compiled Cashbot commit `d8c8e69b565c81e9c943cff65154afc5458b5960` for AMD64 and ARM64
and published tag `anthropic-canary-d8c8e69`. Its matching Golang base was built by
[build 34177618783](https://github.com/EyeLevel-ai/cashbot-go/actions/runs/34177618783).
Both architectures and the multi-architecture manifest passed. The immutable image is
`public.ecr.aws/c9r4x6y5/eyelevel/summary-client@sha256:f510aba3203a4f9768b934b1ef8630f79cc73d21452a085190f20bcce83b1997`.

This image has build and source-provenance evidence. The text canary below used its
source commit, not the summary-client container or a complete on-prem installation.
The chart defaults and production workloads
remain unchanged. Chart validation passed all 254 unit tests, 815 snapshots, and
the full render gate. Strict OpenSpec validation and `git diff --check` passed.

## Canary result and remaining gates

Both successful calls used `claude-sonnet-4-6` through Anthropic's native Messages
API, with the credential reloaded from the existing bash profile. Neither required
an explicit workspace header. No credentials were written to evidence.

| Canary | Runtime and assertion | Result |
| --- | --- | --- |
| Text summary | Cashbot `ratelimit.Client.CreateChat` and native adapter, source `d8c8e69b565c81e9c943cff65154afc5458b5960`; summary retained the synthetic reference and delivery facts | Pass; response `msg_011CeqCZNLeXikbnHhZ6V4HT`; 46 input tokens, 19 output tokens |
| Image extraction | Built ARM64 extraction image above, real `provider_config_for_engine` and `PydanticAIDocumentReviewAgent.request_turn`; one generated image, random code supplied only in pixels, parsed JSON matched exactly | Pass; response `msg_011CeqCbkwkLGy8wm6dDhkgc`; 434 input tokens, 21 output tokens |

The image request inherited the chart-rendered summary engine, without a workflow
override, and retained `parallel_tool_calls: false`. Embedded source commit was
`1ebb14967c9ccf6f8dc113d58a358bc23dac6fdb`. Synthetic image SHA-256:
`16a120c7c88e012082a05f4da81b0f61480f119732db45eb5da661a776ca90c3`.
These are live provider-boundary checks, not full ingestion, queue, or deployed
service tests.

Earlier attempts were rejected for insufficient credit. A separate temporary
organization-scoped key required a workspace header; it was not used for the
successful calls and its owner reports it revoked. The empty workspace listing omitted
Default; its ID was subsequently found through API-key scope metadata.

Before release:

1. Verify the complete chart deployment's application-version compatibility and review
   the custom-engine precedence change for each intended deployment target.
2. Test explicit Anthropic workflow configuration on the existing production services.
   The default-inheritance fix does not change the explicit workflow-engine path and
   is not required for these canaries. A later chart deployment requires its own
   target-specific compatibility checks and rollback state.

## Production rollback

Helm revision 349 changed only the four extraction Deployment image references to
the candidate digest. Revision 350 successfully restored revision 348. Parsed Helm
values and every manifest document matched revision 348 after rollback; all four
Deployments were ready on the original image. Hosted summary binaries were not
changed. This test requires new isolated workflows and buckets, not deployment
changes or account-level provider changes.

## Workflow-only production results

Two synthetic documents ran on the restored production services. Each isolated
workflow supplied native Anthropic `claude-sonnet-4-6`, the existing provider key,
and `maxImages: 5`. Saved workflow readbacks confirmed the engine. The text case
used a custom text-summary field; it did not exercise every built-in summary step.

| Case | Bucket | Workflow | Process | Document |
| --- | --- | --- | --- | --- |
| Text | 33447 | `a8500c47-5388-4ef5-9645-d0073fd07200` | `65bf9c1a-7a45-4d2e-ac85-16866a771953` | `5bb39344-dffe-40b8-a682-19621a40f5c3` |
| Image | 33448 | `478ae621-c59b-484f-8ab6-c8871a3e19bc` | `db64332e-31c2-418e-9cf8-c9ba501ef81d` | `3b78ef59-7321-4db3-9969-dad78d334509` |

Cashbot's retained successful provider responses were:

- Text, `msg_011CeqEM6mRLgF9RWXTFe4Dv`: `Delivery report reference code CANARY-742:
  The delivery arrived on time and was accepted.` (1007 input tokens, 30 output).
- Image, `msg_011CeqEMBrGPoWL1Xnwzauyi`: `{"account_code":"CHECK-93B71F"}`
  (1768 input tokens, 16 output). The prepared request contained one HTTPS image,
  within the five-image cap. This was native Anthropic, not Bedrock S3 transport.

Both then failed in Internal Arcadia's download/load-X-Ray stage with
`canonical v1 workflow reassembly metadata is required`. The captured task payloads
omit `extraction_workflow_metadata_v1`, which the deployed `dbccfa8` loader requires.
The captured persisted workflow and summary input also lack that metadata packet.
The candidate `1ebb149` image has the same loader and would not fix this failure.
The first-run metadata failure is explained by the outdated dispatch Lambda below.
Neither reconciliation nor QA ran in that first attempt, and neither document
produced a verified final extraction.

Private requests, provider responses, and failure traces remain under
`openspec/work/add-anthropic-workflow-engine-service/prod-20260908/` and each
document's authenticated `layout/processed/<process>/<document>-extract-trace/`
prefix. Retain the two test resources for this unresolved handoff issue. Workflow
capture expires on 2026-09-09 at 06:00 UTC. No customer workflow was changed.

## Dispatch Lambda update and production retest

The API saved valid workflow artifacts. The deployed `PreProcessTrainFile` binary,
source `711ec9398b042663e51beae91be365b677a053b8`, did not recognize `anthropic`.
Its service parser silently changed it to `hosted`. Recomputing the workflow hash
after that change selected a nonexistent S3 artifact path. The metadata loader
allowed missing artifacts, and dispatch sent an incomplete task to Arcadia.
Production-function replay against both database records reproduced exactly one
changed path, `engines.all.service`. The old parser found zero artifacts; the
Anthropic-aware parser preserved the stored hash and found all three artifacts.

[Build 34183930309](https://github.com/EyeLevel-ai/cashbot-go/actions/runs/34183930309)
built only `pre-process-lambda` from pushed source
`d8c8e69b565c81e9c943cff65154afc5458b5960`. The deployed immutable image is:

`903713046261.dkr.ecr.us-west-2.amazonaws.com/pre-process-lambda@sha256:2866bb3de85807d22f81a57a5f34366b13ec26193fcb19b5f8faf8f1ca5d21b9`

The release script completed successfully. Lambda is Active with a Successful
update. AWS runtime configuration and event-source mapping hashes are unchanged;
the enabled SQS mapping retains `ReportBatchItemFailures`. The build bundles the
current production config. Its only differences from the previous bundled config
are the API-only compiled-JSON write gate and extraction-capture account allowlist;
neither changes the dispatcher provider or storage settings. The previous image,
available for rollback through the same release script, is:

`903713046261.dkr.ecr.us-west-2.amazonaws.com/pre-process-lambda@sha256:e46187b21c39f3ac268cb44c1c54c8d9b4f0775f4f31b625b6394fe1b2c059e3`

Both test sources, workflows, buckets, and provider settings were reused unchanged.
New document submissions preserve the first-run failures and their evidence.

| Case | New process | New document | Result |
| --- | --- | --- | --- |
| Text | `bda771fd-d952-4ac2-99d7-060cf634e4ec` | `4ae2b199-8067-4db5-b998-b0c6642e7a16` | Correct summary; metadata and reconciliation pass; QA fails before model invocation because no derived images exist |
| Image | `27475459-a0e2-4414-92b6-3223178fdc85` | `651c2e18-f08b-453a-963f-ed208890f8b1` | Complete; authoritative extraction is `{"account":{"account_code":"CHECK-93B71F"}}` |

Both dispatch and API-ingress packets contain reassembly metadata. Both Cashbot
provider calls succeed using `claude-sonnet-4-6`. Reconciliation runs the no-conflict
path without a model call in both cases; these tests do not certify a reconciliation
provider request. Image QA makes one Anthropic call with one image, below the
configured five-image cap, and returns the correct code. Provider response ID is
`msg_011CeqGyJS8jVAobJFvTbZay`. Final save, callback, and `get_extract` agree.

Text QA receives `page_images: []` and raises
`ImageEvidenceError: remote_url transport requires derived page image URLs` during
agent setup. The extracted summary and metadata are present. This is a separate
image-evidence requirement in the unchanged extraction runtime, not a missing
metadata failure or a rejected Anthropic request. The document has no final extract.

The update fixes compatibility with Anthropic. Provider parsing remains unchanged.
The separate Cashbot `require-extraction-workflow-metadata` change rejects missing
metadata before dispatch. Internal Arcadia's `review-source-text` change supplies
original source text when page images are absent. Neither fix is deployed in this
record; a fresh text canary remains required after deployment.

Retest evidence is retained beneath the existing private root in `dispatch-retest/`:
68 text and 146 image trace objects, with indexed SHA-256 filenames to avoid the
macOS filename-length failure. It includes dispatch inputs, API ingress, stage
inputs/outputs, provider requests/responses, terminal diagnostics, and final output.
Owner remains release coordinator; expiry remains 2026-09-15 pending disposition.
