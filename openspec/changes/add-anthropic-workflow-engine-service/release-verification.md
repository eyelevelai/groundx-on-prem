# Anthropic release verification

Status as of 2026-09-08 UTC: native text and multimodal provider canaries pass
with the reloaded bash-profile credential. Full deployment validation remains gated.
No production deployment, workflow assignment, credential change, or customer-data
mutation occurred.

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

## Current runtime inventory

- Both hosted summary servers expose healthy endpoints. Their running binaries embed
  clean commit `589d4c9fddbf2b0bb066b8cdf6bab9e80822887f`, which contains the Cashbot
  native-provider prerequisite. The native adapter bytes match current master.
- Kubernetes context `gxprod`, namespace `eyelevel`, Helm release `groundx`, revision
  `348`: all four extraction workloads use
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
successful calls and has not been revoked. The empty workspace listing omitted
Default; its ID was subsequently found through API-key scope metadata.

Before release:

1. Verify the complete chart deployment's application-version compatibility and review
   the custom-engine precedence change for each intended deployment target.
2. Use the approved deployment procedure and recorded rollback state before assigning
   Anthropic in production. The current production image and provider remain unchanged.
