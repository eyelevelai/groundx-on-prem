# extract-agent-key-precedence Specification

## Purpose
TBD - created by archiving change gx-158-self-hosted-extraction-fails-with-the-bundled-summary. Update Purpose after archive.
## Requirements
### Requirement: extract-agent-secret-wins-agent-key

When the chart attaches its extraction-agent Secret to an extract workload (rendered from `admin.apiKey` or `extract.agent.apiKey`, or named by `extract.agent.existingSecret`), the workload's `GROUNDX_AGENT_API_KEY` SHALL resolve from that Secret regardless of the names or order of the Secrets in `cluster.secrets`. This holds for `extract-agent`, `extract-api`, `extract-download` and `extract-save`, in both `src/groundx` and `helm/`.

Polarity: `finalize success` (the agent Secret's key is the one the pod receives).

#### Scenario: Shared Secret sorts after the agent Secret
- **GIVEN** the in-cluster summary engine (`admin.apiKey` set) and `cluster.secrets` containing `eyelevel-secret-credentials` with `GROUNDX_AGENT_API_KEY` set to an OpenAI key
- **WHEN** the extract workloads are rendered and their environment is resolved with Kubernetes precedence (later `envFrom` entries win)
- **THEN** each of `extract-agent`, `extract-api`, `extract-download` and `extract-save` resolves `GROUNDX_AGENT_API_KEY` to the `admin.apiKey` value
- **AND** the OpenAI key is not the resolved value for any of them.

#### Scenario: Conflicting Secrets sort before and after, in both list orders
- **GIVEN** conflicting Secrets that sort before (`aaa-conflict`) and after (`zzz-conflict`) the agent Secret, each setting `GROUNDX_AGENT_API_KEY`
- **WHEN** `cluster.secrets` lists them shared-first and then shared-last
- **THEN** the agent Secret is the last `envFrom` entry of every extract workload in both orders and the resolved key is the agent Secret's.

#### Scenario: Provider key supplied in values
- **WHEN** `extract.agent.apiKey` is set for a hosted provider (Anthropic or Bedrock)
- **THEN** the agent Secret is the last `envFrom` entry and the pod receives that key (values-keyed hosted providers get the agent Secret's key by design).

#### Scenario: Existing Secret
- **WHEN** `extract.agent.existingSecret` is true
- **THEN** the Secret named by `extract.agent.secretName` (default `extract-agent-secret`) is the last `envFrom` entry of `extract-agent`, `extract-download` and `extract-save`
- **AND** every key it carries overrides the same key from earlier Secrets, and a key it lacks still resolves from them.

### Requirement: no-agent-secret-no-change

When no agent Secret is attached (hosted provider with no key in values and no `existingSecret`), the chart SHALL render `envFrom` for extract workloads exactly as before this change, so `GROUNDX_AGENT_API_KEY` keeps coming from the shared Secret.

Polarity: `skip unrelated repair path` (the precedence rule must not act when nothing is attached).

#### Scenario: Hosted provider without a key
- **WHEN** `extract.agent.serviceType` is a hosted provider, no `apiKey` and no `existingSecret` are set, and the shared Secret sets `GROUNDX_AGENT_API_KEY`
- **THEN** no agent Secret appears in any extract workload's `envFrom` and the resolved key is the shared Secret's
- **AND** the `envFrom` list is identical to the pre-change render.

#### Scenario: Backward compatibility during rollout
- **WHEN** an operator upgrades with a shared Secret that carries no `GROUNDX_AGENT_API_KEY`
- **THEN** the pod environment still carries the agent Secret's key and no pod fails to start for a missing key (no required `secretKeyRef` is introduced).

### Requirement: precedence-scope-limited-to-extract

Only the extract workloads that already receive the agent Secret SHALL change. Layout, workspace, summary and other workloads' `envFrom` SHALL NOT change, and `helm/templates` SHALL stay byte-identical to `src/groundx/templates`.

Polarity: `skip unrelated repair path`.

#### Scenario: Unrelated workloads unchanged
- **WHEN** the full chart is rendered before and after the change with the same values
- **THEN** only the `envFrom` ordering of the extract workloads differs.

#### Scenario: Mirror stays identical
- **WHEN** `.build/bin/verify-storage-contract.py` runs
- **THEN** template-tree mirror verification passes.

