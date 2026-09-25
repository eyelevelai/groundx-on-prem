# GX-34: `summary-inference` must not require a live HuggingFace credential

- **Ticket**: GX-34
- **Author**: Gowtham Kandasamy <gowtham.kandasamy@valantor.com>
- **Date**: 2026-09-24

## Why

A HuggingFace access token was found packaged (leaked) alongside the `summary` model artifact
(`upload.groundx.ai/summary/model/current/g34b.tar.gz.part.04`). Investigation on the
`groundx-validation` test cluster confirmed the token is live and is being used: the
`summary-inference` pod authenticates to `huggingface.co` on every startup to re-verify a file
(`chat_template.jinja`) that the HuggingFace client library already knows, from the original
authenticated download, does not exist for this model — a fact it caches in a `.no_exist` marker
specifically so it does not need to ask again. Gemma's repository is gated, so even this
re-verification call requires authentication; without a valid credential it fails with `401`
(`GatedRepoError`), and the pod never becomes ready. Confirmed by deleting the credential and doing
a real restart: the pod hard-fails and never recovers.

Removing the leaked token without a fix would break self-hosted summary on every on-prem
deployment's next restart or fresh install.

Setting `HF_HUB_OFFLINE=1` on the `summary-inference` container tells the HuggingFace client to
trust the local cache (including that `.no_exist` marker) instead of re-verifying it over the
network. Confirmed on `groundx-validation`: with the credential deleted and this variable set, the
pod starts cleanly and a real document summarizes successfully end to end, with no HuggingFace
network call of any kind.

## What Changes

- Add `HF_HUB_OFFLINE=1` to the `summary-inference` container's environment, scoped to that service
  only (`mapPrefix == "summary"`), in the shared `templates/app/inference.yaml` used by
  `layout-inference`, `ranker-inference`, and `summary-inference`. No effect on the other two
  services.
- Mirror the change into `helm/` (verified byte-identical to `src/groundx/` for this file before the
  change).

### Explicitly out of scope

- Rebuilding the `g34b` artifact to exclude the leaked credential files, and rotating/revoking the
  leaked token. Both require HuggingFace account access this change does not have; tracked
  separately on GX-34, owned by the ticket's other assignee.
- Any change to `layout-inference` or `ranker-inference`. Neither depends on HuggingFace.
- The pre-existing pre-upgrade migration-job hang and the `layout-inference` OCR crash found during
  the same investigation, both filed separately (GX-69 and a GX-49/GX-50 follow-up), unrelated to
  this template.

## Capabilities

### New Capabilities
- `summary-inference-credential-independence`: `summary-inference` must be able to start, load its
  model, and serve a summarization request using only its local model cache, with no HuggingFace
  credential present and no successful network path to `huggingface.co` required. No existing spec
  covers this pod's HuggingFace dependency.

### Modified Capabilities
(none)

## Impact

**Blast radius**: `src/groundx/templates/app/inference.yaml`, its `helm/` mirror, and the
`inference_test.yaml` snapshot. No values schema change, no change to `layout-inference` or
`ranker-inference` behavior (the added block is conditional on `mapPrefix == "summary"`), no change
to any other template.

**Affected environments**: every on-prem deployment with self-hosted summary enabled
(`summary.create: true`), at its next `helm upgrade`. Deployments using a third-party summary
engine (OpenAI, Azure, etc.) never create this pod and are unaffected.

**Rollout**: in place. `summary-inference`'s pod template gains one environment variable; the
chart's existing config-hash mechanism rolls the pod on `helm upgrade` the same way any other
config-map change does. No new resource, no Service/Deployment identity change.

**Rollback**: revert the one template change (and its mirror); no stateful resource or data is
touched in either direction.

**Open design questions**: none — verified directly on a real cluster with the real pinned
`summary-inference` image before writing this proposal (see `design.md` for the evidence trail).
