# Metadata guard and source-text production release

Both isolated synthetic workflows passed on 2026-09-08. The TXT workflow previously
failed during QA because it had no derived images. QA now receives its original source
text. The image workflow continues to use its page image. Customer defaults, credentials,
source files, and workflow definitions remain unchanged.

## Deployment

Target: AWS account `903713046261`, `us-west-2`; Kubernetes context `gxprod`, namespace
`eyelevel`, Helm release `groundx`, revision `351`.

| Component | Source | GitHub Actions build | Immutable image |
| --- | --- | --- | --- |
| PreProcessTrainFile | `2137e1a2603abeb405a7c52223cdaf8806729749` | [34224245271](https://github.com/EyeLevel-ai/cashbot-go/actions/runs/34224245271) | `903713046261.dkr.ecr.us-west-2.amazonaws.com/pre-process-lambda@sha256:4b9453beb8b0173da48fee1c7f6c75bef6fe6801095db52261f4c6602cc1d138` |
| Extract API, download, agent, save | `a9fef08328fa0809e8785aa28dbe3b7988663c5a` | [34224248758](https://github.com/eyelevelai/internal-arcadia-agents/actions/runs/34224248758) | `public.ecr.aws/c9r4x6y5/eyelevel/extract@sha256:6f056226fa48286572f68cada2336235591bc195712ce238a304afb87434686d` |

Both builds passed, including both extraction architectures and their manifest. Lambda
is Active with a Successful update; runtime configuration and SQS mapping are unchanged.
The mapping remains enabled with `ReportBatchItemFailures`.

The image-only Helm rollout used the existing release chart and configuration. Its actual
manifest matches the server dry run: four Deployment image replacements and 55 unchanged
resources. All four workloads are ready and report the source SHA in `/app/BUILD_COMMIT`.
Old pods exited before canary submission. Worker grace periods remain 900 seconds.

Rollback: use the Cashbot release script with the previous Lambda image
`903713046261.dkr.ecr.us-west-2.amazonaws.com/pre-process-lambda@sha256:2866bb3de85807d22f81a57a5f34366b13ec26193fcb19b5f8faf8f1ca5d21b9`.
For extraction, `helm --kube-context gxprod rollback groundx 350 -n eyelevel --wait
--timeout 20m` restores the previous image and configuration.

## Canary results

Both saved workflows still select native Anthropic `claude-sonnet-4-6` with
`maxImages: 5`. This test does not use Bedrock or S3 image transport.

| Case | Bucket | Workflow | Process | Document |
| --- | --- | --- | --- | --- |
| Text | 33447 | `a8500c47-5388-4ef5-9645-d0073fd07200` | `bc0d4082-620b-4bac-b0e3-7b0eb1d27a01` | `45b8c2fb-7e26-408e-b8be-474248ea3628` |
| Image | 33448 | `478ae621-c59b-484f-8ab6-c8871a3e19bc` | `3124d141-d99e-449d-9c5c-3ef28d4d52ea` | `4a9f51cc-ecbd-4b70-97ec-88f556ee018e` |

- Text final output: `{"account":{"delivery_summary":"Delivery report reference code CANARY-742: The delivery arrived on time and was accepted."}}`.
- Image final output: `{"account":{"account_code":"CHECK-93B71F"}}`.
- Both API-ingress packets include `extraction_workflow_metadata_v1`.
- Both reconciliation stages pass the no-conflict path without a provider call.
- Text QA receives all original text and zero images. Its Anthropic response is
  `msg_011CeqxLPMRwRQxrBDUL9YiM`.
- Image QA receives one image and no text-fallback section. Its Anthropic response is
  `msg_011CeqxMkBqm361c7AQMx3FT`.
- Private `_source_text` survives the QA handoff but is absent from terminal save and
  final customer JSON. Both callbacks persist successfully; `get_extract` matches.

## Evidence and limits

Private evidence remains under
`openspec/work/add-anthropic-workflow-engine-service/prod-20260908/source-text-retest/`.
It contains raw final outputs, X-Rays, unchanged workflow readbacks, stage inputs and
outputs, model requests and responses, callback evidence, and deployment verification.
All 145 text and 146 image trace objects pass their saved SHA-256 checks. Stage records
report complete capture with no missing artifacts. Earlier runs remain unchanged.

| Artifact | SHA-256 |
| --- | --- |
| Text final JSON | `6f03c61318461b31699166f3b71a32434135a1bf299f0c3e914c0e30bdbb6ac3` |
| Image final JSON | `1e48e36cc4e9a30fef0f12cbae0007ff8de1451e537a57c356a19ac6e0cbcaeb` |

These canaries prove image-free statement QA and unchanged image-backed statement QA.
They do not prove live conflict reconciliation, meter or charge model calls, deliberate
missing-metadata rejection, or a complete on-prem chart release. Those are not outcomes
of the two synthetic workflows. Future chart rollouts require target-specific
compatibility checks described in the chart upgrade notes.

The isolated resources were deleted during provider closeout. Successful private
boundary evidence remains retained for debugging, with retention review due
2026-09-15. Temporary secret-bearing Helm snapshots are not durable evidence;
Helm retains the rollback revision. See `provider-closeout.md` for disposition.
