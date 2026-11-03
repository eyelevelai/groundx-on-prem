## Why

With the documented shared Secret, the extraction pod sends the OpenAI key to the bundled summary service and fails authentication (403). The chart builds each extract workload's `envFrom` from one merged map of Secrets and renders it in sorted name order (`templates/app/celery.yaml`, `templates/app/api.yaml`). Kubernetes lets a later `envFrom` entry win, so `eyelevel-secret-credentials` (which sets `GROUNDX_AGENT_API_KEY` to the OpenAI key) sorts after the chart's `extract-agent-secret` ("ex" < "ey") and overrides it, whatever order the operator lists `cluster.secrets` in. The chart-rendered agent Secret holds `admin.apiKey` for the in-cluster summary engine, which is the key summary-api accepts. Chart 0.2.7 renders the same order.

The Linear body (GX-158) is the authority; its on-prem code links are stale only in that `celery.yaml` now merges through `groundx.fileAccess.workloadSecrets`. The bug is unchanged.

This is the chart half of GX-158. The second half (summary-api's reply missing `id`, `object`, `model`, `choices[].index`) is fixed in ai-server and verified in internal-arcadia-agents and cashbot-go; both must land for self-hosted extraction to work.

## What Changes

- When the chart attaches its extraction-agent Secret (rendered from `admin.apiKey` or a values key, or an `existingSecret`) to an extract workload, `GROUNDX_AGENT_API_KEY` resolves from that Secret regardless of other `cluster.secrets` names or list order. Required for `extract.agent`; applied to `extract.api`, `extract.download` and `extract.save` through one shared helper (all four currently get the wrong value). Design chooses the mechanism (agent Secret rendered last in `envFrom` vs an explicit `env` `secretKeyRef` hybrid) and states the `existingSecret` consequence.
- Hosted-provider path with no key in values and no `existingSecret` attaches no agent Secret, so `GROUNDX_AGENT_API_KEY` keeps coming from the shared Secret exactly as today.
- Values-keyed hosted providers (anthropic `engines.default.apiKey`, bedrock `extract.agent.apiKey`, `summary.existing.apiKey`) intentionally get the agent Secret's key after the fix (plan-gate adjustment P1).
- Changes are made in `src/groundx/` and mirrored by hand into `helm/` (no regen script; `verify_mirrors()` in `.build/bin/verify-storage-contract.py` enforces byte equality of the template trees).
- Tests, run through `.build/bin/validate-helm.sh`: helm-unittest cases in `src/groundx/tests/` with conflicting Secrets sorting before and after the agent Secret in both list orders, plus anthropic and bedrock cases; a check that renders both `src/groundx` and `helm/`, resolves the extraction pod's env with Kubernetes precedence, and asserts it equals the summary key. Snapshots are hand-patched, never regenerated with `-u`, and verified with `helm unittest` and `.build/bin/verify-helm-snapshots.py`.
- README: a `GROUNDX_AGENT_API_KEY` precedence note and the minimum python-api image release that carries the ai-server reply fix (P2).

## Capabilities

### New Capabilities
- `extract-agent-key-precedence`: the extraction workloads' `GROUNDX_AGENT_API_KEY` resolves from the chart's agent Secret whenever one is attached, independent of `cluster.secrets` naming or order.

### Modified Capabilities

None. No existing spec in `openspec/specs/` changes requirements.

## Impact

- **Affected files:** `templates/app/celery.yaml`, `templates/app/api.yaml`, the extract helpers under `templates/_helpers/app/` (`extract-agent.tpl`, `extract-api.tpl`, `extract-download.tpl`, `extract-save.tpl`), the same files under `helm/templates/`, `src/groundx/tests/` (unittest cases and hand-patched `__snapshot__` entries), `.build/bin/validate-helm.sh` plus a new render-and-resolve check, and `README.md`. No `values.schema.json` or `values.yaml` change.
- **Blast radius:** any release upgrading to this chart rolls the extract api, agent, download and save pods once (rendered `envFrom`/`env` change). Operators whose shared Secret sets `GROUNDX_AGENT_API_KEY` to an OpenAI key while also using the in-cluster summary engine are the ones whose behavior changes (the key becomes `admin.apiKey`); operators with values-keyed hosted providers also now get the agent Secret's key (P1). Operators with no agent Secret see no change. Layout, workspace and summary workloads never get the agent Secret and are untouched.
- **Environments / state:** no stateful resource, PVC, or data is touched. Chart-only; no deploy, apply or helm install is run by this change (PRIVILEGED repo: lint, template and unittest only).
- **Rollback / rollforward:** `helm rollback` to the previous release restores the old render; rolling forward needs only a normal chart upgrade. Release target branch is a hand-off detail (next release branch vs `main`).
- **Cross-service:** a compatible python-api image is required for the whole fix to work (ai-server reply shape); the minimum release is named in the README. Cluster proof (acceptance criterion 4) is a manual open task before merge, outside this repo's automated checks.
- **Open design questions:** none beyond the mechanism choice, which `design.md` resolves.
