# GroundX On-Prem — Architecture Notes

> **Audience / lens:** This repo is being mapped as a **node in a cross-repo dependency graph**
> and assessed for AI-first conversion. It is an **infrastructure repo** (Helm + legacy Terraform).
> There is **no application source code and no app-level API contract** here — the "contract"
> this repo exposes is its **deployment surface** (`values.yaml` + `values.schema.json`).
>
> Verified by reading/grepping the tree on 2026-06-08. Chart version `0.2.5`.
>
> **Status:** Phase 1 (orientation) + Phase 3 deep dive #1 (`extract`) complete. Claims are marked
> verified vs inferred inline; §14 tracks what's still open. Sections 8–12 are the assessment
> captures (agent boundary, external services, privileged capabilities, cross-repo coupling,
> contracts); §13 is the per-module deep dive; §14 is open questions.

---

## 1. What this system does (3 sentences)

GroundX On-Prem packages the commercial **GroundX RAG platform** (document ingestion + hybrid
text/vector search + re-ranking + LLM summarization) as a Kubernetes deployment that can run
**air-gapped**, with no required runtime dependency on EyeLevel/GroundX SaaS. The actual product
ships as **pre-built private container images**; this repo contains only the Helm chart, example
configs, operator tooling, and (legacy) Terraform to install and scale those images. Deployment is
either onto an existing cluster via Helm, or end-to-end on AWS via the deprecated Terraform path.

## 2. Tech stack

- **Helm 3.8+** (chart `apiVersion: v2`) — primary delivery mechanism. Go templating.
- **Kubernetes** — targets: `eks`, `aks`, `gke`, `openshift`, `minikube` (selected via `cluster.type`).
- **Bash** — operator CLI (`bin/`).
- **Terraform** — legacy AWS/EKS provisioning (deprecated 2025-11-04; see §10).
- **helm-unittest** — snapshot-based chart tests; run in GitHub Actions.
- Backing services it can deploy or attach to: **Redis, MySQL (Percona XtraDB), MinIO/S3,
  OpenSearch, Kafka (Strimzi)/SQS**, optional **Neo4j (`graph`, legacy only)**, Prometheus/Grafana.
- App pods run **Python (Gunicorn + Celery + supervisord)**, **Go**, and **GPU inference (vLLM)**.

## 3. Directory map

| Path | Responsibility |
|------|----------------|
| `README.md` | Master deployment guide (~700 lines). Authoritative ops doc. |
| `sample.values.yaml` | Minimal starter config users copy → `values.yaml`. |
| **`src/`** | **Source of truth.** Where charts are authored. |
| `src/build.sh` | Packages charts → `.tgz`, `helm repo index`, **uploads to `s3://eyelevel-upload/helm/`**. |
| `src/groundx/` | **The main Helm chart** (entire app). values.yaml, schema, templates, helpers, tests, prereqs, example overlays. |
| `src/opensearch/` | Wrapper chart for OpenSearch. |
| `src/containers/` | Dockerfiles for support images (redis, opensearch, vllm, busybox). |
| `helm/` | **Near-duplicate published copy** of `src/groundx` **minus `tests/`** (see §8 agent boundary). |
| `helm-releases/` | Pre-packaged `.tgz` chart releases (groundx 0.1.3 → 0.2.5 + prereq charts). Build artifacts. |
| `bin/` | Operator CLI: `operator`, `environment`, `uuid`, `estimate`, `container`, `clear`, `shared/`. |
| `terraform/` | **Legacy** AWS VPC/EKS + `groundx-operator` Helm orchestration. Deprecated. |
| `monitoring/` | Prometheus `ServiceMonitor`, Grafana dashboard JSON, prometheus values. |
| `doc/` | Architecture diagram images. |
| `.github/workflows/helm-tests.yml` | CI: runs `helm unittest src/groundx`. |

## 4. Entry points

There is no runtime "main" in this repo. The operational entry points are:

1. **`helm install groundx groundx/groundx -n eyelevel -f values.yaml`** — the real install path
   (chart pulled from `https://registry.groundx.ai/helm`).
2. **`bin/operator [component] [-c|-t]`** — bash orchestrator (legacy Terraform-driven; deploy/destroy
   functional groups `init`/`services`/`app`, individual pods, or services).
3. **`bin/environment [aws-vpc|eks] [-c|-t]`** — provisions AWS infra via Terraform (legacy).
4. **`src/build.sh`** — maintainer-only: packages and publishes charts to S3.
5. Template render root: `src/groundx/templates/` (Helm renders these; `_helpers/*.tpl` drive everything).

## 5. How to run / test locally (verified from CI + manifests)

```bash
# Lint/render the chart
helm template src/groundx -f src/groundx/values/minikube/values.yaml

# Unit tests (exactly what CI runs — .github/workflows/helm-tests.yml)
helm plugin install https://github.com/helm-unittest/helm-unittest.git
helm unittest src/groundx                       # snapshot tests in src/groundx/tests/

# Generate UUIDs required for admin.apiKey / admin.username
bin/uuid

# Real install (needs a cluster + license)
helm repo add groundx https://registry.groundx.ai/helm && helm repo update
helm install groundx groundx/groundx -n eyelevel -f values.yaml
```

CI trigger: every push/PR/release on all branches → `helm unittest src/groundx` + JUnit report.

## 6. Core data flow

**Ingestion pipeline** (the central path; pods scale on pipeline throughput):
```
upload (API) → file storage (MinIO/S3) + queue (Kafka/SQS)
  → pre-process (Celery) → process (Celery)
  → layout pipeline:  layout-api → layout-ocr (tesseract) → layout-inference (GPU vision model)
                      → layout-map → layout-correct → layout-save
  → layout-webhook (callback aggregation)
  → summary-client → summary-api → summary-inference (GPU LLM / vLLM, or external OpenAI/Azure)
  → persisted to OpenSearch (vectors+text) + MySQL (metadata) + file store (objects)
```
**Search path:**
```
groundx (main API/LB)  → OpenSearch hybrid query → ranker-api → ranker-inference (GPU re-ranker)
                       → results
```
**Where state lives:** MySQL (`db`, metadata), OpenSearch (`search`, vectors+text), MinIO/S3
(`file`, source files + semantic objects), Redis (`cache`), Kafka/SQS (`stream`, pipeline queues).

## 7. Key abstractions to internalize

1. **Data-driven templating.** There are only ~5 workload templates
   (`templates/app/{api,celery,inference,golang,metrics}.yaml`). Each `range`s over a *list of
   service names* (e.g. `groundx.api.services`) and dynamically resolves a per-service config dict
   via `include (printf "groundx.%s.settings" $name)`. **All per-pod detail lives in `_helpers/*.tpl`,
   not in the workload YAML.** To understand any pod you must read its `.settings` helper.
2. **Service abstraction with `existing: {}` swap-out.** Every backing service (`cache`, `db`,
   `file`, `search`, `stream`) is either deployed by the chart or attached to external infra by
   setting `existing:` + `serviceType` (e.g. `file.serviceType: s3`, `stream.serviceType: sqs`).
3. **Config-hash restart pattern.** Deployments annotate `config-hash: {{ ...sha256sum }}` of their
   ConfigMaps, so editing `config.py`/`gunicorn_conf.py`/`supervisord.conf` forces a rollout.
4. **Throughput-driven HPA.** Autoscaling = pipeline-throughput estimate (`throughput.tpm`) +
   a pod-type metric (api→latency, queue→backlog, task→Celery backlog, inference→request rate).

---

## 8. (c) AGENT BOUNDARY — generated / duplicated / off-limits

- **`src/groundx/` is the source of truth.** Hand-edit charts here.
- **`helm/` is a near-identical published copy of `src/groundx` with `tests/` removed** and
  `Chart.yaml` key-reordered (verified via `diff -rq`: only difference is the missing `tests/` dir
  and reformatted Chart.yaml). Treat `helm/` as a **generated/mirrored artifact** — editing it by
  hand will drift from `src/`. ⚠️ There is **no script in-repo that regenerates `helm/` from `src/`**
  and no check that asserts they match — the duplication is maintained manually/externally. **This is
  a latent drift risk and a prime AI-first cleanup target.**
- **`helm-releases/*.tgz`** are build outputs of `src/build.sh` (`helm package`). Never edit.
- **`src/groundx/tests/__snapshot__/*.snap`** are **generated golden files** from `helm-unittest`.
  Do not hand-edit; regenerate with `helm unittest -u src/groundx`. CI (`helm-tests.yml`) enforces
  that rendered output matches these snapshots — **this is the check that guards template changes.**
- **`terraform/**/.terraform.lock.hcl`** are generated lockfiles.
- No codegen of *other* repos happens here (no OpenAPI/SDK generation, no submodules).

## 9. (a) EXTERNAL SERVICES CALLED (repo-wide)

| Service | Where / config key | Hardcoded vs configurable | Auth | Capability |
|---|---|---|---|---|
| **`registry.groundx.ai/helm`** | README, `build.sh` index URL | Hardcoded (default repo) | none (public) | **Pulls the Helm chart** itself. |
| **`public.ecr.aws/c9r4x6y5`** | `main.tpl` → `groundx.imageRepository` | Default; overridable via `admin.imageRepository` | ECR public (optional `imagePullSecrets`) | **Pulls all GroundX container images.** |
| **`upload.groundx.ai`** | inference init-containers (`/summary/model/current/g34b.tar.gz`, `/ranker/model/current/model.tar.gz`) | **Hardcoded** in inference templates | none | **Downloads GPU model weights at pod startup** via `wget`. ⚠️ Air-gap blocker: must be mirrored for offline installs. |
| **`api.groundx.ai`** | `extract.callbackUrl` (e.g. `https://api.groundx.ai/api` in `values.phoenix.yaml`); README shows it as the host you *replace* with your on-prem endpoint | **Configurable** (`extract.callbackUrl` + `extract.callbackApiKey`) | API key (`callbackApiKey` / `admin.apiKey`) | **RAG/ingest callback** for the `extract` subsystem. This is the only edge that can phone home to hosted GroundX, and it is opt-in. |
| **OpenAI** (`api.openai.com/v1`) | `summary.existing` / `engines.default` / `extract.agent` (`serviceType: openai\|openai-base64`) | Configurable; off by default (self-hosted GPU LLM is default) | `apiKey` | External **LLM summarization / extraction** instead of on-prem vLLM. |
| **Azure OpenAI** (`*.openai.azure.com`) | same as above, `serviceType: azure` | Configurable | `apiKey` | Same as OpenAI, Azure-hosted. |
| **Google Sheets / Drive** | `extract.save.driveId`, `extract.save.templateId`, `extract.save.gcpCredentials` | Configurable; off unless `extract.save` enabled + creds set | GCP service-account JSON (`gcpCredentials`) → secret | **`extract.save` pod can write extraction results to a Google Sheet.** Verified in Phase 3 (see §13). |
| **AWS S3** (`*.s3.*.amazonaws.com`) | `file.existing` + `file.serviceType: s3` | Configurable | AWS creds / IRSA | Object storage backend (replaces MinIO). |
| **AWS SQS** (`sqs.*.amazonaws.com`) | `stream.existing`/`stream.topics` + `serviceType: sqs` | Configurable | AWS creds / IRSA | Pipeline queues (replaces Kafka). |
| **AWS RDS / ElastiCache** (`*.rds`, `*.cache.amazonaws.com`) | `db.existing`, `cache.existing` | Configurable | user/pass | External MySQL / Redis. |
| Helm repos: nvidia (ngc), percona, minio, strimzi (quay), opensearch, prometheus-community, neo4j; RedisLabs GitHub releases | README + values overlays | Hardcoded in docs/commands | none | **Install-time** dependency charts/operators. |
| `eyelevel.ai`, `dashboard.eyelevel.ai/xray`, `documentation.groundx.ai`, YouTube | README only | n/a | n/a | **Docs/marketing only** — no runtime call. |

**Distinguishing the GroundX endpoints touched here:**
- **RAG/search + ingest API** = `api.groundx.ai/api` — referenced only as the `extract` *callback*
  target and as the host users substitute with their own on-prem LB. No other runtime call.
- **Model artifact host** = `upload.groundx.ai` — weights only, deploy-time.
- **Chart registry** = `registry.groundx.ai/helm`.
- **Workspace / project-lifecycle API** = **NOT touched** (see §11).
- **Hosted MCP server** = **NOT touched** (no MCP references anywhere in the repo).

## 10. Privileged capabilities ⚠️ (flag prominently)

This repo's tooling holds **broad cluster- and cloud-control authority**:
- **`bin/operator`** can **deploy *and destroy*** (`-c` clear mode) Helm releases and Terraform
  stacks for any component, including backing data stores (`db`, `file`, `search`) — i.e. it can
  **delete stateful infrastructure**.
- **`bin/environment`** can **create/destroy AWS VPCs and EKS clusters** via `terraform apply
  --auto-approve` / `destroy` (see `bin/shared/util:deploy()`).
- **`src/build.sh`** runs `aws s3 cp ... s3://eyelevel-upload/helm/ --recursive` — **publish rights**
  to the public chart bucket.
- Charts request **GPU resources**, **PersistentVolumes**, **LoadBalancer Services/Ingress**
  (`alb.ingress…`, `route.openshift.io`), **RBAC** (`rbac.authorization.k8s.io`,
  `apiregistration.k8s.io`, `external.metrics.k8s.io`), and a **custom APIService/metrics server**.
- Init containers run **arbitrary `wget | tar` from `upload.groundx.ai`** with shell — supply-chain
  surface for the model weights.
- Secrets in plaintext defaults in example values (OpenSearch `password`, MinIO `minio123`) — example
  only, but a footgun if copied to prod.

## 11. (b) CROSS-REPO COUPLING

**Verified conclusion: this repo has _no_ in-tree code dependency on any other `groundx-*` repo.**

| Other repo | Coupling found here | Type | Where the contract lives |
|---|---|---|---|
| **`groundx-python`** | SDK appears as **usage examples in `README.md`** (`from groundx import GroundX`). **Plus** (Phase 3): `extract-config-py.yaml` generates Python that does `from groundx.extract import AgentSettings, ContainerSettings, …` — a **generated-config binding** to a `groundx.extract` package in the `eyelevel/extract` image. | Reference-only for the SDK; **soft code-contract** for `groundx.extract` (config text must match that package's constructors). | Class signatures live in the image / `groundx-python`-family package, **not here**; unschematized — see §13. |
| **`groundx-workspace-runner`** | **NOT defined here.** All "workspace" hits are the container `/workspace` working directory (legacy Terraform inference pods), unrelated to a workspace-runner subsystem. No Helm subsystem, chart, image, or values key for a workspace runner exists. | None | Not in this repo. |
| **`groundx-web-ui-scaffold`** | **None.** No reference. This repo ships no UI. | None | Not in this repo. |

**Re: the specific question — does the `groundx-workspace-runner` Helm subsystem live here, and how
does the on-prem runner relate to the hosted Workspace API?**
→ **No.** This chart deploys only the **ingest + search/RAG** stack (`groundx`, `layout*`, `summary*`,
`ranker*`, `pre-process`, `process`, `queue`, `upload`, `summary-client`, `layout-webhook`, `extract`,
`metrics`) plus backing services. There is **no Workspace runner, no Workspace API client, and no MCP
server** defined or referenced. If other repos' on-prem docs mention a `groundx-workspace-runner`
Helm subsystem, **it is not vendored or defined in this repo** — that edge's contract must live in the
workspace-runner repo itself, not here. The on-prem ↔ hosted-Workspace relationship is **not
observable from this codebase.**

## 12. (d) CONTRACTS THIS REPO EXPOSES

Role = **infra**, so the contract is the **deployment surface**, not an app API.

| Contract | Schema-enforced? | Location |
|---|---|---|
| **Helm values surface** (`values.yaml`) | **YES — JSON Schema** (`values.schema.json`, 1693 lines, `additionalProperties:false` on most blocks → strict). Top-level: `global, licenseKey, namespace, imageType, languages, logLevel, mode, admin, cluster, serviceAccount, engines, busybox, cache, db, file, search, stream, summary, groundx, layout, layoutWebhook, metrics, preProcess, process, queue, ranker, summaryClient, upload, dashboard, extract, integration, throughput`. | `src/groundx/values.schema.json` (+ mirror in `helm/`) |
| **Rendered K8s objects** (Deployments, Services, ConfigMaps, Secrets, HPA, Ingress, ServiceMonitor, APIService) | Validated indirectly via **helm-unittest snapshots** (`tests/__snapshot__/*.snap`) | `src/groundx/templates/` |
| **Operator CLI component names** | Inline / unschematized (bash arrays `valid_groups/valid_apps/valid_services` in `bin/shared/util`) | `bin/shared/util`, `bin/operator` |
| **Generated config files** (`config.py`, `gunicorn_conf.py`, `supervisord.conf`, `config.yaml`) consumed by the *images* | Inline templates; the real contract (field names the app reads) lives in the **container images**, not here | `src/groundx/templates/resources/*` |
| **Published Helm repo index** | Helm `index.yaml` (generated) | `s3://eyelevel-upload/helm/`, `registry.groundx.ai/helm` |

`mode` value (`all` default, or `ingest`) toggles ingest-only deployments. `imageType` (`chainguard`)
switches to hardened images + UID 65532 (else 1001).

---

## 13. Phase 3 deep dive #1 — the `extract` subsystem

**Single responsibility:** an **optional, LLM-driven structured-extraction pipeline**, separate from
the core ingest pipeline. Disabled by default (`extract.enabled: false`). Newest area of the repo
(recent commits tune `reasoningEffort` / `model_kwargs`). Most relevant component for AI-first work.

**Files:** 5 helpers (`_helpers/app/extract*.tpl`), 1 secrets helper (`secrets.tpl`), 3 ConfigMap
resources (`extract-config-py.yaml`, `extract-supervisord-conf.yaml`, `extract-gunicorn-conf-py.yaml`).
Rendered through the **generic** `app/celery.yaml` (workers) and `app/api.yaml` (HTTP) — no dedicated
workload template. All four pods share the **`<repo>/eyelevel/extract:<chartVersion>`** image.

**The 4 pods** (each a `<name>.create` flag; `extract.services` lists the 3 Celery workers):
| Pod | Type | Celery queue | Role |
|---|---|---|---|
| `extract.api` | Gunicorn HTTP | — | Entry point + `/health`; optional ingress; other Celery pods `wait-for-extract` on it. |
| `extract.download` | Celery worker | `download_queue` | Fetches source files to process. |
| `extract.agent` | Celery worker | (queue) | **The LLM agent** — calls a model to extract structured data. |
| `extract.save` | Celery worker | (queue) | Persists results; **optionally writes to Google Sheets**. |

Workers run `celery -A celery_agents.app worker` under supervisord; **broker = Redis (`cache`)**.

**LLM endpoint resolution (`extract.agent`), verified:**
- `serviceType` default = `eyelevel` (self-hosted). Options: `eyelevel`, `openai`, `openai-base64`, `azure`.
- `baseUrl`: if `serviceType` is **not** openai/openai-base64 **and** `summary` is deployed → defaults
  to the **in-cluster summary API** (`groundx.summary.api.serviceUrl`). For `openai*` → empty (SDK uses
  `api.openai.com`). Overridable via `extract.agent.apiBaseUrl`.
- `modelId` / `model.kwargs` / `reasoningEffort`: default to the self-hosted summary model's values
  unless an external `serviceType` is set or explicit values given.
- `apiKey`: defaults to `admin.apiKey`; injected as env **`GROUNDX_AGENT_API_KEY`** via a Secret
  (`<service>-secret`), unless `existingSecret: true`.
- **Default posture is air-gap-safe:** with no `serviceType`, the agent talks to the in-cluster vLLM
  summary API, not OpenAI.

**Callback to GroundX (verified):** the generated `config.py` builds `GroundXSettings(api_key=…,
base_url=…)` where `base_url` = `extract.callbackUrl` → **defaults to the in-cluster `groundx` service
`/api`**, `api_key` = `extract.callbackApiKey` → defaults to `admin.username`. Only when a user sets
`extract.callbackUrl` explicitly (e.g. `https://api.groundx.ai/api` in `values.phoenix.yaml`) does this
edge leave the cluster. So **the `api.groundx.ai` edge is opt-in, not default.**

**The real contract (important for the dependency graph):** `extract-config-py.yaml` emits Python that
does `from groundx.extract import (AgentSettings, ContainerSettings, ContainerUploadSettings,
GroundXSettings)`. **The chart's contract here is a code-level binding to a `groundx.extract` Python
package baked into the `eyelevel/extract` image** — the constructor signatures/field names are the
contract, and they live in that package (image / `groundx-python`-family), **not in this repo**. Helm
only generates config text; it does not validate against those classes. Changing a field name in the
image silently breaks rendering compatibility — no schema guards it.

**Autoscaling:** agent throughput default **9000 tpm / worker / thread**; queue-backlog threshold 10;
HPA metric `<name>:task` + `<name>:throughput` (same pattern as core Celery pods).

**Non-obvious / gotchas:**
- `extract` can use a **separate object store** from the main `file` service (`extract.file.*` overrides
  bucket/creds/endpoint independently) — a second S3/MinIO egress to track.
- `extract.save` Google Sheets path requires a **GCP service-account JSON** mounted as a secret — a new
  credential class and external egress (`sheets.googleapis.com`) not present elsewhere in the chart.
- Two new env-injected secrets: `GROUNDX_AGENT_API_KEY` (LLM/callback) and the save secret.

## 14. Open questions / not-yet-verified

- **How is `helm/` generated/synced from `src/groundx/`?** No in-repo script or CI step does it.
  Likely a manual `cp` or an external release process. **Confirm before trusting `helm/` as canonical.**
- **Does the running app phone home for license validation?** `licenseKey` is injected into
  `config.yaml`, but the validation logic lives in the (opaque) container images — cannot confirm
  whether it requires outbound calls to a GroundX licensing endpoint at runtime. README implies the
  key is "looked up," but air-gap claims suggest offline validation. **Verify with a real install /
  network trace.**
- **Is `upload.groundx.ai` model download avoidable for air-gapped installs?** It's hardcoded in
  inference init-containers; presumably weights can be pre-seeded into the PVC, but the mechanism
  isn't documented in-repo. **Verify.**
- **`graph` (Neo4j) service** is wired in `bin/shared/util`, `bin/operator`, and legacy
  `terraform/shared/node_assignments.tf` (+ `helm.neo4j.com` repo) but has **no presence in the
  current `src/groundx` chart/values**. Confirm it's legacy-Terraform-only and dead in the Helm path.
- ~~**`extract` subsystem maturity**~~ — RESOLVED in Phase 3, see §13. Remaining sub-question: the
  exact constructor signatures of `groundx.extract.*` classes (in the image) — needed to know what a
  safe config change looks like; not visible from this repo.
- **`integration` block** drives in-cluster integration tests (`integrationTests` in config.yaml);
  confirm it never reaches external services.
```
