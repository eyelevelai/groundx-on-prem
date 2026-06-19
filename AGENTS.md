# AGENTS.md — groundx-on-prem

## What this repo is

`groundx-on-prem` is the **infra** repo of the GroundX workspace: a **Helm chart** (chart version
`0.2.5`, Helm 3.8+ / Go templating) plus a Bash operator CLI and a **legacy, deprecated** Terraform
path that package the commercial **GroundX RAG platform** (document ingestion + hybrid text/vector
search + re-ranking + LLM summarization) for **self-hosted / air-gapped Kubernetes**. There is **no
application source code here** — the product ships as **pre-built private container images**
(`public.ecr.aws/c9r4x6y5` by default); this repo only contains the chart, example configs, operator
tooling, and legacy Terraform that install and scale those images. The contract this repo exposes is
its **deployment surface** (`values.yaml` + `values.schema.json`), not an app API. K8s targets:
`eks`, `aks`, `gke`, `openshift`, `minikube` (selected via `cluster.type`). It has **no in-tree code
dependency on any other `groundx-*` repo** (verified).

## How to run and test

- **Lint / render:** `helm lint src/groundx` · `helm template src/groundx -f src/groundx/values/minikube/values.yaml`
- **Test:** `helm unittest src/groundx` (requires the `helm-unittest` plugin:
  `helm plugin install https://github.com/helm-unittest/helm-unittest.git`)
- **Helpers:** `bin/uuid` generates the UUIDs needed for `admin.apiKey` / `admin.username`
- **Real install** (needs a cluster + license):
  `helm repo add groundx https://registry.groundx.ai/helm && helm repo update`
  then `helm install groundx groundx/groundx -n eyelevel -f values.yaml`
- **Quality gates that MUST pass before any PR merges:**
  - `helm unittest src/groundx` — snapshot tests; **this is the CI gate** (`.github/workflows/helm-tests.yml`, runs on every push/PR/release). It is the **only** check that guards template changes.
  - `helm template src/groundx -f src/groundx/values/minikube/values.yaml` — render check (must render cleanly).

## Privileged operations — Tier 3 ⚠️ DO NOT RUN UNPROMPTED

This repo is marked **`privileged: true`** in `workspaces/groundx/repos.yml`. Its tooling holds broad
cluster- and cloud-control authority. **Read these scripts freely; never execute the destructive ones
without explicit human authorization.**

- **`bin/operator`** deploys **and DESTROYS** (`-c` clear mode) Helm releases and Terraform stacks for
  any component — **including stateful data stores (`db`, `file`, `search`)**. It can delete stateful
  infrastructure.
- **`bin/environment`** creates/destroys **AWS VPCs and EKS clusters** via `terraform apply
  --auto-approve` / `terraform destroy` (`bin/shared/util:deploy()`). Full cloud teardown, **no
  confirmation gate**.
- **`src/build.sh`** runs `aws s3 cp … s3://eyelevel-upload/helm/ --recursive` — **publish rights to
  the PUBLIC Helm chart bucket** (`registry.groundx.ai/helm`). Maintainer-only.
- Charts request **GPU resources, PersistentVolumes, LoadBalancer Services/Ingress** (ALB, OpenShift
  Routes), **RBAC** (`rbac.authorization.k8s.io`, `apiregistration.k8s.io`, `external.metrics.k8s.io`),
  and a **custom APIService / metrics server**.
- Init containers run **arbitrary `wget | tar` from `upload.groundx.ai`** — a supply-chain surface for
  GPU model weights.

## Agent boundaries — READ BEFORE EDITING

- **You MAY edit:** `src/groundx/` (the **source of truth** — all chart changes go here), `src/opensearch/`,
  `src/containers/`, `monitoring/`, `bin/` logic (with the privileged caveats above), docs.
- **You MUST NOT hand-edit:**
  - **`helm/`** — a **near-identical published mirror** of `src/groundx` (tests/ removed, `Chart.yaml`
    reordered). Edit `src/groundx/`, then sync to `helm/`. Reason: **mirror**. ⚠️ **Enforcement: NONE** —
    there is no in-repo script that regenerates `helm/` from `src/` and no check that asserts they match.
    Manual sync, latent drift; a prime cleanup target (logged in `service.yaml` `known_gaps`).
  - **`src/groundx/tests/__snapshot__/*.snap`** — generated golden files. Do not hand-edit; regenerate
    with `helm unittest -u src/groundx`. Reason: **generated**. Enforcement: `helm-tests.yml` CI asserts
    rendered output matches these snapshots.
  - **`helm-releases/*.tgz`** — build outputs of `src/build.sh` (`helm package`). Never edit.
  - **`terraform/**/.terraform.lock.hcl`** — generated lockfiles. Never edit.
- **`terraform/`** is **legacy / deprecated** (2025-11-04). Don't build on it; prefer the Helm path.

## Where specs live

- OpenSpec: `openspec/changes/` (active), `openspec/changes/archive/` (shipped).
- Workflow: `/opsx:propose <change>` → `/opsx:apply` → `/opsx:archive`. Default driver `/opsx:continue`.
- Superpowers methodology is active in the harness and triggers automatically.

## Repo-specific gotchas

- **`helm/` ↔ `src/groundx/` duplication has no regen script and no drift check** — the single most
  important hazard. A change to `src/groundx/` that isn't mirrored into `helm/` silently ships stale
  templates. Sync both, every time.
- **`upload.groundx.ai` model-weight download is HARDCODED** in inference init-containers — an
  **air-gap blocker**; weights must be mirrored for offline installs (mechanism not documented in-repo).
- **The `groundx.extract` config binding is UNSCHEMATIZED.** `extract-config-py.yaml` generates Python
  that does `from groundx.extract import (AgentSettings, ContainerSettings, ContainerUploadSettings,
  GroundXSettings)` — binding to constructor signatures in the `eyelevel/extract` **image**, not this
  repo. A field rename in the image **silently breaks rendering**; nothing validates it.
- **The `api.groundx.ai` callback is opt-in and air-gap-safe by default** — `extract.callbackUrl`
  defaults to the in-cluster `groundx` `/api`; it only leaves the cluster if a user sets it explicitly.
  It is the **only** edge that can phone home to hosted GroundX.
- **Plaintext secret defaults in example values** (OpenSearch password, MinIO `minio123`) — example
  only, but a footgun if copied to prod.
- **Data-driven templating:** there are only ~5 workload templates
  (`templates/app/{api,celery,inference,golang,metrics}.yaml`); each `range`s over a list of service
  names and resolves per-service config via `include (printf "groundx.%s.settings" $name)`. **All
  per-pod detail lives in `_helpers/*.tpl`** — to understand any pod, read its `.settings` helper.
- **Config-hash restart pattern:** Deployments annotate `config-hash: {{ …sha256sum }}` of their
  ConfigMaps, so editing `config.py`/`gunicorn_conf.py`/`supervisord.conf` forces a rollout.
- **`existing: {}` swap-out:** every backing service (`cache`, `db`, `file`, `search`, `stream`) is
  either deployed by the chart or attached to external infra via `existing:` + `serviceType`.
- **Neo4j (`graph`)** is wired in legacy `bin/`/Terraform but absent from the current `src/groundx`
  chart — treat as legacy-Terraform-only / likely dead in the Helm path (unconfirmed).
- The strict deployment contract is **`src/groundx/values.schema.json`** (1693 lines,
  `additionalProperties: false` on most blocks). Changes there have broad blast radius.

## OpenSpec

OpenSpec manages the **documentation lifecycle** for this repo (proposal → specs → design →
tasks). **Implementation** is done with **Superpowers** (brainstorm → plan → TDD → review →
finish), which is ambient in the harness and triggers automatically. All spec work runs inside
this repo on the feature branch.

**Schema:** `spec-driven` (official)   **Role:** `infra`   **Profile:** `custom`   **Default command:** `/opsx:continue`

Per-artifact content rules live in `openspec/config.yaml`. Inspect templates and runtime
guidance with `openspec instructions <artifact>`.

### Default slash command

`/opsx:continue` — the recommended driver for this repo.
- `/opsx:ff` — small, low-risk changes; all artifacts at once.
- `/opsx:continue` — large or correctness-sensitive flows; one gated artifact at a time.
- `/opsx:explore` — think first; useful when the approach is unclear.

### Skills used by the artifacts

- Open design questions in a proposal → `superpowers:brainstorming`.
- Given/When/Then scenarios in specs → `superpowers:test-driven-development`.
- Architectural decisions → `architectural-decision-records` skill; write ADRs to
  `docs/adr/<LINEAR-TICKET>-<kebab>.md` (Linear ticket prefix mandatory). Cross-service
  decisions live in the **producing** repo and are referenced from consumers' `design.md`.
