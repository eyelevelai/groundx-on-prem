## Why

On an install that stores files in a private S3 bucket and summarizes with the bundled self-hosted model, the summary worker sends the model plain bucket links, the model downloads them without credentials, and S3 answers 403. Documents complete without image summaries and nothing reports a failure. The worker (cashbot-go) can instead read each page with its own storage credentials and send the bytes inside the request, for an engine whose config sets `inlineImages: true`. The chart's job is to let an operator set that on an engine and to pass it into the worker's `config.yaml`. Nothing is turned on by default.

## What Changes

- **Render the flag only when the operator sets it.** In the engine loop of `src/groundx/templates/resources/config-yaml.yaml`, beside `maxImages`, render `inlineImages: true` for an engine only when that engine's values set `inlineImages` to true. The check is a plain truthiness test on the engine's own value. There is no derived default, no storage-type condition and no check of whether the engine is the chart's own. An engine that leaves it unset or sets it to false renders no `inlineImages` key.
- **Schema.** Add a boolean `inlineImages` entry under `engines.default` in `values.schema.json`. That block rejects unknown keys, so the key is refused today.
- **Values documentation.** Add a commented `engines` example to `values.yaml`, written in plain English for operators: a real example engine, that the setting is off unless set, that a page the worker cannot read fails the document, that setting `engines` replaces the built-in engine so `default` must repeat its settings, and that `true` on an engine outside the cluster sends page images there. It is comments only and changes no rendered output.
- **Mirror.** `src/groundx` is edited first. `helm/` receives the same three file edits, byte-identical.
- **Tests.** Helm-unittest cases in `src/groundx/tests/resources_test.yaml` check that the key is absent when unset or false (including on an S3 engine), present when true, and that a string is rejected by the schema. Fixtures `values.inline-images-s4.yaml` and `values.inline-images-remote-eyelevel.yaml`, and the cases that only checked the derived default (in-cluster MinIO and AIStor, S4, remote `eyelevel` engine, `openai` engine), are removed.
- **Snapshots.** The `resources`, `golang` and `metrics` snapshots equal the chart base branch (`origin/0.3.0`). They are checked through `.build/bin/validate-helm.sh` and never regenerated with `helm unittest -u`.
- **Remove the earlier GX-93 OpenSpec material.** The archived change `openspec/changes/archive/2026-10-30-gx-93-self-hosted-summary-cannot-read-page-images-from-a-private/` and the durable spec `openspec/specs/engine-inline-images-config/spec.md` described the derived default and the override. Neither was merged to the base branch, so both are removed, and this change replaces them. The GX-93 note in `openspec/config.yaml` that describes the derived default is dropped or reworded to match.

## Capabilities

### New Capabilities
- `engine-inline-images-config`: how the chart validates the per-engine `inlineImages` value and renders it into the application `config.yaml` only when the operator sets it true, and the rule that every install that does not set it renders the same bytes as before.

### Modified Capabilities
- None. The `maxImages` requirements in `doc-summary-image-limit-config` do not change.

## Impact

- **Files (groundx-on-prem):** `src/groundx/templates/resources/config-yaml.yaml`, `src/groundx/values.yaml`, `src/groundx/values.schema.json` and their `helm/` copies; `src/groundx/tests/resources_test.yaml` and its `inlineImages` fixtures; `openspec/config.yaml`; the archived change and durable spec named above.
- **Blast radius.** An install that does not set `inlineImages` renders a `config.yaml` identical to the base branch, so `helm upgrade` rolls nothing for it. An install that sets it to true on an engine gets a changed `config-yaml-map` Secret, which every Go-service Deployment and the metrics Deployment mount and hash into `config-hash`, so each rolls once. No Kubernetes resource is added or removed, and no PVC, database or other stateful resource is touched.
- **Environments.** Any install, on any storage type, whose operator sets the value. In-cluster MinIO, AIStor and S4 installs are unaffected unless the operator sets it.
- **Activation.** The chart alone changes no behavior. The key has effect only once a summary-client image that reads it is running, and cashbot-go decodes its config without strict mode, so an older image ignores the key. The image tag follows `Chart.AppVersion` unless the operator sets `summaryClient.image`. This change does not name the chart release that first carries the key; publishing the chart is a separate privileged maintainer step.
- **Failure behavior to expect.** With `inlineImages` on, a page the worker cannot read fails the request and the document, as it does today for an `openai-base64` engine. This is stated in the `values.yaml` comment.
- **Security.** Setting `inlineImages: true` on an engine outside the cluster sends that install's page-image bytes to the engine's `baseUrl`. It is an explicit operator choice, and the `values.yaml` comment says so.
- **Rollback and roll-forward.** Removing the value from the engine, or running `helm rollback`, drops the key and rolls the same Deployments once more. Pinning `summaryClient.image` to an image without the worker change makes the worker ignore the key. Because setting `engines` replaces the implicit default engine and the schema requires `engineId`, an operator who has never set `engines` must declare the full `engines.default` block to opt in.
- **Cross-service.** This chart is the producer of the rendered `inlineImages` key in each engine block of `config.yaml`. cashbot-go consumes it and `groundx-studio-harness` documents it (see the workspace change's `contract.md`). Neither is edited here. See the workspace `openspec/changes/gx-93-self-hosted-summary-cannot-read-page-images-from-a-private/` for cross-service coordination.
- **Open design questions:** none.
