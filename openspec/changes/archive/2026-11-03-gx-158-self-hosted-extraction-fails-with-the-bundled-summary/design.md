## Goals / Non-Goals

Goals: the extract workloads that receive the chart's agent Secret resolve `GROUNDX_AGENT_API_KEY` from it, independent of `cluster.secrets` names and order (see proposal.md for the failure). Non-goals: any change to the shared prereq Secret, `values.schema.json`, `values.yaml`, other workloads, or the ai-server reply shape.

## Decisions

Invariant: when the chart attaches its agent Secret to an extract workload, no other Secret may override the agent Secret's keys, whatever their names or order; and when it attaches none, nothing changes.

### 1. Mechanism: agent Secret rendered last in `envFrom` (not an explicit `secretKeyRef`)

`templates/app/celery.yaml` and `templates/app/api.yaml` build `envFrom` by ranging a merged map, which Go templates iterate in sorted key order. The fix removes the agent Secret from that range and emits it as the final `envFrom` entry, because Kubernetes lets later `envFrom` entries win. One helper, `groundx.extract.agent.lastSecret` in `templates/_helpers/app/extract-agent.tpl`, returns the agent Secret name only when the workload is an `extract.*` entry and that name is already in the workload's own `secrets` (the set built in `extract.agent.settings`, `extract.api.settings`, `extract.download.settings`, `extract.save.settings`) captured before `workloadSecrets` is merged in. Tying it to the chart's own attachment keeps the three attach conditions (values key, `existingSecret`, `admin.apiKey`) in one place and leaves workloads without the agent Secret untouched.

Rejected: an explicit `env` `secretKeyRef` for `GROUNDX_AGENT_API_KEY`. A required reference makes the pod fail to start (`CreateContainerConfigError`) when an `existingSecret` omits the key; an optional reference has uncertain "key absent" precedence against `envFrom` and would need an empirical spike. The optional-`secretKeyRef` external-semantics assumption does not apply: this design uses no `secretKeyRef`, optional or otherwise, so no spike is required.

### 2. `existingSecret` consequence

With `extract.agent.existingSecret: true` the Secret named by `extract.agent.secretName` is attached to `extract-agent`, `extract-download` and `extract-save` (not `extract-api`, unchanged) and now renders last. Every key it carries, not only `GROUNDX_AGENT_API_KEY`, overrides the same key from earlier Secrets. A key it lacks still resolves from the shared Secrets, so no pod fails to start. Operators who relied on the shared Secret winning over their existing Secret get the existing Secret's value after upgrade.

### 3. Values-keyed hosted providers

Anthropic (`engines.default.apiKey`), Bedrock (`extract.agent.apiKey`) and `summary.existing.apiKey` already render the agent Secret with that key, so after this change they receive it rather than the shared Secret's (plan-gate adjustment P1). A hosted provider with no key and no `existingSecret` attaches nothing and keeps the shared Secret's key exactly as today.

### 4. Compatibility and rollout

Classification: additive in values and schema (no key added or removed); the rendered `envFrom` order changes, so any release upgrading to this chart rolls the extract api, agent, download and save pods once. `helm rollback` restores the old render. No schema, migration, stateful resource or deploy step is involved; PRIVILEGED limits apply (lint, template, unittest only). Producer contract shapes confirmed: not applicable, this repo exposes no API shape here. The whole GX-158 fix also needs a python-api image carrying the ai-server reply fix; the README names the minimum release (P2, release number recorded in the README at implementation from the ai-server change).

### 5. Mirror and tests

`src/groundx` is edited first and mirrored by hand into `helm/templates`; `verify_mirrors()` in `.build/bin/verify-storage-contract.py` byte-compares the trees. Tests: `src/groundx/tests/extract_test.yaml` and `anthropic_test.yaml` (exact `envFrom` lists for the four workloads with conflicting Secrets before and after, both list orders, plus Anthropic, Bedrock and existing-Secret cases) and `.build/bin/verify-extract-agent-key.py`, which renders both chart surfaces and resolves the container environment with Kubernetes precedence against fixture shared Secrets, asserting the summary key. The script is wired into `validate-helm.sh`. The existing `api_test` and `celery_test` snapshots swap the `extract-agent-secret` and `extract-save-secret` entries; they are hand-patched, never regenerated with `-u`, and checked with `helm unittest` and `.build/bin/verify-helm-snapshots.py`. The helm-unittest suite needs the throwaway OCR credentials file (`files/ocr/gcv-test.json` in each chart) that `validate-helm.sh` generates; a filtered run of only `extract_test.yaml` does not need it.

No ADR: the decision is a single template-ordering choice recorded here.
