## Why

The hotfix-0.2.7 merge (`07d332fc`) brought in a render check that fails when the extract agent uses Bedrock (`extract.agent.serviceType: bedrock`) and the extract file storage is anything other than `s3` (`src/groundx/templates/_helpers/app/extract-agent.tpl:273-276`). The check matched the runtimes of that time: cashbot-go and the extract services sent Bedrock page images only as `s3://` references. GX-88 now changes both runtimes so that on `minio` and `s4` storage they send page images as resized JPEG data URLs, while `s3` storage keeps `s3://` references (Linear GX-88, desired behavior 7, added on 2026-10-15 after Ben replied "yes these definitely need to be fixed" on 2026-10-14). Once the runtimes support it, this chart check is the only thing still blocking Bedrock on the default MinIO or AIStor store and on S4, so it is removed.

Line references in this proposal are to groundx-on-prem commit `102850ea` unless another ref is named.

The other half of this amendment, extraction trace capture, needs no change in this repo. The layout webhook pod already mounts the shared cashbot-go config (`src/groundx/templates/_helpers/app/golang.tpl:34` lists `layoutWebhook`; `src/groundx/templates/app/golang.yaml:160-170` mounts `config-yaml-map`), and that config's `upload` block carries the storage type (`src/groundx/templates/resources/config-yaml.yaml:682-700`). The trace-capture fix is in cashbot-go alone.

## What Changes

- Remove the Bedrock storage check (the `$serviceType` lookup and the `if`/`fail` block at lines 273-276) from `src/groundx/templates/_helpers/app/extract-agent.tpl` and from its mirror `helm/templates/_helpers/app/extract-agent.tpl`. On 2026-10-15, `cmp` reported the two copies identical at `102850ea`. The other checks in `groundx.extract.agent.validateImageSettings` stay: image transport, long-edge bounds, `maxRequestImages`, and JPEG qualities.
- No other template, default, or `values.schema.json` change. The schema already types `extract.agent.serviceType`, `extract.file.serviceType`, and `file.existing.serviceType` as plain strings, with no condition that names Bedrock.
- In the existing suite `src/groundx/tests/extract_test.yaml` (assertion-only, no snapshot), replace "bedrock extract config rejects non-S3 storage" (`:525-536`) with two passing cases:
  - Bedrock with the chart's default storage renders `service="bedrock"` and `type="minio"`.
  - Bedrock with `s4` storage renders `type="s4"`.
- Keep unchanged the Bedrock `s3` case (`:498-524`) and the Bedrock cases at `:537-719`. Those cases render with `s3` storage and cover an omitted endpoint, model, or provider key, and the agent secret on each worker.
- One assertion-only case in the same file in which Bedrock on the default storage, with `extract.agent.minLongEdgePx` 900 and `extract.agent.targetLongEdgePx` 899, still fails with "extract.agent.minLongEdgePx must be less than or equal to extract.agent.targetLongEdgePx". It asserts against `extract-supervisord-conf.yaml`, the first template that fails. An invalid `extract.agent.imageTransport` cannot reach the helper: `values.schema.json` declares it as an enum of `pil`, `data_url` and `remote_url`, so Helm rejects any other value at schema validation, before any template runs. The long-edge bound is the only check in `validateImageSettings` that values passing the schema can reach. The case being removed is the suite's only `failedTemplate` assertion on `validateImageSettings`. Without this new case, nothing in the suite would show that the helper still rejects invalid settings after the check is removed.
- **Added at the user's direction at the GX-88 S4 review gate on 2026-10-15, not caused by the Bedrock change:** one assertion-only `s4` pass-through case beside the existing `minio` storage case ("extract storage inherits account-wide values field by field", `:128`). With `file.existing.serviceType: s4`, it asserts:
  - the cashbot-go config renders `service: s4`;
  - the layout config renders `uploadType="s4"` with the bucket in `uploadURL`;
  - the extract config renders `type="s4"` and its URL.

  The archived S4 change proved this pass-through with a render check, not with a committed test.
- The chart stays at `0.2.8`, the version both `Chart.yaml` files already carry. No second bump.

## Capabilities

### New Capabilities
- `extract-bedrock-storage`: the chart renders the extract agent with `serviceType: bedrock` for every file storage type (`minio`, `s4`, `s3`), and the remaining image-setting checks still reject invalid settings.

### Modified Capabilities
- `s4-storage-type`: two requirements narrow to "no template change other than the Bedrock storage check":
  - "The chart documents `s4` as a storage type without changing any default", which currently says "No chart template changes";
  - "Chart version 0.2.8 is the minimum for s4", which currently says "Templates, defaults, and snapshots SHALL NOT change".

  The "s4 reaches every consumer unchanged" scenario names the committed helm-unittest case as the validator for the rendered cashbot-go `service`, the layout `uploadType` and `uploadURL`, and the extract `type` and URL. Its other checks (`ingest` mode, the `nc -z` storage-wait init containers, and no `amazonaws` in the render) stay covered by the render check. The byte-identical render scenarios still hold, because removing a `fail` does not change the output of any input that already rendered.
- `object-store-install-and-upgrade`: "Community MinIO sample values stop shipping while installed stores keep working" currently says "every chart template and default ... SHALL remain unchanged". It narrows the same way, and its byte-identical render scenario still holds.

## Impact

- **Blast radius.**
  - Only inputs that failed to render now render: Bedrock with a storage type other than `s3`.
  - Every input that rendered before is expected to render byte-identically, because the removed lines are whitespace-trimmed template actions that emit no text. `.build/bin/validate-helm.sh` confirms this when no snapshot changes. At `102850ea`, no snapshot under `src/groundx/tests/__snapshot__/` mentioned Bedrock.
  - Existing installs therefore get no rendered change and no rollout from this change.
  - Affected environments: any cluster deployed from this chart that selects Bedrock with `minio` storage (community MinIO, or AIStor on the default settings) or with `s4` storage. That means customer self-hosted installs and the validation EKS cluster.
- **What could break on rollout.**
  - **Older images.** Chart 0.2.8 can run with cashbot-go or extract images that predate the GX-88 releases, for example through explicitly pinned tags. On non-S3 storage, those images refuse Bedrock at these points:
    - cashbot-go returns "bedrock internal image conversion requires AWS S3 storage" (`pkg/ratelimit/request_passthrough_images.go:251,255` at cashbot-go `041dc06a`);
    - the extract service raises "Bedrock image transport requires S3 storage" on its remote-URL path (`classes/image_evidence.py:482` at internal-arcadia-agents `ea67325f`).

    The chart is published only after the 0.2.8 images exist (the existing release gate). No chart check catches explicitly pinned older tags.
  - **Trust boundary.** On `minio` and `s4` storage, the GX-88 runtime changes send page-image bytes to AWS Bedrock in the request body; only `s3` storage keeps sending S3 references. This chart change is what allows an install to select that. The groundx-studio-harness docs describe it.
- **Data and stateful resources.** None. No store, volume, Secret, or schema changes.
- **Rollback and roll-forward.**
  - Chart 0.2.7 carries the same check (`extract-agent.tpl:275` at `07d332fc`), so `helm upgrade` to 0.2.7 with Bedrock on non-`s3` storage fails at render.
  - Before going back, switch the extract agent to another service, or switch the extract storage to `s3`.
  - Installs that do not use Bedrock on non-S3 storage roll back as before.
  - To roll forward, correct the values and upgrade again.
- **Release order.** Unchanged:
  1. groundx-python releases and internal-arcadia-agents raises its pin.
  2. cashbot-go and ai-server merge.
  3. The images publish.
  4. The maintainer publishes chart 0.2.8.
  5. The groundx-studio-harness docs merge.
- **Validation.**
  - `.build/bin/validate-helm.sh` with helm v3.19.0 (`GX_ON_PREM_HELM`) passes, and no file under `src/groundx/tests/__snapshot__/` changes.
  - `cmp` of the two `extract-agent.tpl` copies.
  - `.build/bin/verify-storage-contract.py`.
  - The MinIO closure grep, re-run because the new spec text names the `minio` storage type.
  - `helm/` has no tests directory, so the cases live only in `src/groundx/tests/`.
- **Out of scope.** Unchanged by this proposal:
  - other templates and defaults, and `values.schema.json`;
  - the README, `AGENTS.md`, and values comments, which contained no Bedrock text at `102850ea`;
  - the S4 README review fixes, which are a separate apply round;
  - live Bedrock calls (tests only, per the ticket's definition of done).
- **Open design questions.** None. The invalid-transport case above is a scope item for the proposal gate, not an open design question.
