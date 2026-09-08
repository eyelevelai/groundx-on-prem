# Anthropic release verification

Status as of 2026-09-08 UTC: release remains gated. Native text canary execution
reached Anthropic, which rejected the request for insufficient account credit.
No successful text or multimodal canary is claimed. No production deployment,
workflow assignment, credential change, or customer-data mutation occurred.

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

This is a build and source-provenance check, not a successful provider canary or a
complete on-prem installation test. The chart defaults and production workloads
remain unchanged. Chart validation passed all 254 unit tests, 815 snapshots, and
the full render gate. Strict OpenSpec validation and `git diff --check` passed.

## Canary result and remaining gates

The real Cashbot `ratelimit.Client.CreateChat` dispatch and native Messages adapter
ran locally from current master with synthetic text and `claude-sonnet-4-6`.
Anthropic returned HTTP 400, `invalid_request_error`, for insufficient credit,
request `req_011Ceq7d9JrFHXw3hAQqhvJA`. This proves provider reachability and error
propagation, not successful summarization. No further provider calls were made
after the account error was identified. The image canary was not run.

A subsequent retry returned the same HTTP 400 insufficient-credit error, request
`req_011CeqB8wyeyiK4NWASvUj71`. The configured account remains blocked; no image
canary or production change followed the retry.

Before release:

1. Fund the Anthropic account and pass text and multimodal extraction-agent canaries.
2. Verify the complete chart deployment's application-version compatibility and review
   the custom-engine precedence change for each intended deployment target.
3. Use the approved deployment procedure and recorded rollback state before assigning
   Anthropic in production. The current production image and provider remain unchanged.
