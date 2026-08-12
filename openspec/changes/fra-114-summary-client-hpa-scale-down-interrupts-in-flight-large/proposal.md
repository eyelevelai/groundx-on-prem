## Why

`summary-client`'s SQS worker chain (cashbot-go `QueueServer`) exits immediately on SIGTERM today
— the chart never sets `terminationGracePeriodSeconds`, so the implicit Kubernetes default (30s)
applies, and whatever document is mid-chain when the HPA scales the pod away is lost. The SQS
message then redelivers after the 15-minute visibility timeout and the whole summary chain
restarts from the top; for the largest documents (bucket 24: 213- and 140-chunk docs, `48→3`
scale-down in ~10 min) this adds a ≥15-minute tail latency, and for documents whose run genuinely
exceeds one visibility window it becomes a redelivery loop (FRA-114).

The producer side of this fix — cashbot-go's opt-in graceful drain via
`config.QueueServer.DrainSeconds` — is FINALIZED (contract `drainSeconds-config`, confirmed at
cashbot-go commit `f82196e4`). `DrainSeconds` lives on the single shared `config.QueueServer`
struct (`pkg/config/types.go:279`), and **all five** Go queue binaries construct their
`server.NewQueueServer` with their own `QueueServer`-typed config block —
`ProcessTrainFile`→`cfg.ProcessFileServer`, `FileUploadIngest`→`cfg.UploadFileServer`,
`QueueTrainFile`→`cfg.QueueFileServer`, `PreProcessTrainFile`→`cfg.PreProcessFileServer`,
`ProcessFiles`→`cfg.SummaryServer` — and the drain wait itself
(`q.Cfg.DrainSeconds`, `pkg/server/queue.go:344,357`) is the one generic path all five binaries
share. So all five config blocks have a live reader for `drainSeconds` today, not just
`summaryClient`'s. That config key has nowhere to render today: the chart's Go queue-service
`replicas` schema blocks accept only `desired/max/min`, `golang.yaml` never sets
`terminationGracePeriodSeconds`, and `config-yaml.yaml` never emits `drainSeconds` for any of the
five blocks. This proposal is the CONSUMER half — it makes the chart able to render both settings
for **all five Go queue services** (`summaryClient`/`process`/`upload`/`queue`/`preProcess`) — so
an install can opt in by setting `replicas.gracePeriod` in its values. No chart default changes;
the concrete sizing (`gracePeriod: 900` / `drainSeconds: 870`) is set by the private FraudX values
override, which is out of scope for this repo.

## Blast Radius & Rollout

- **Rollout mechanics:** `golang.yaml` (Go-service Deployment template, shared by ~20 services
  across `summaryClient`/`queue`/`process`/`preProcess`/`upload`) and `config-yaml.yaml` (the
  shared app-config ConfigMap) both change, so every install redeploys these two rendered objects
  on its next `helm upgrade` for this chart version. **No install today sets `replicas.gracePeriod`**
  (verified: no `gracePeriod` key exists anywhere under `src/groundx/values*.yaml` or
  `src/groundx/values/`) — both additions are guarded (`hasKey $rp "gracePeriod"` in `golang.yaml`;
  equivalent presence check in `config-yaml.yaml`), so for every current install the rendered
  Deployment and ConfigMap are **byte-identical to today's**. The `helm-unittest` snapshot suite
  (unchanged expected output for every existing fixture that doesn't set `gracePeriod`) is the
  check that proves this no-op — a snapshot diff on those fixtures is a regression.
- **Affected environments:** dev/staging/prod (and any other chart consumer) are all in the
  "no-op" bucket above — none currently sets `gracePeriod`. The only environment expected to
  exercise the new path is the FraudX on-prem install, once its separate (out-of-scope) values
  override sets `summaryClient.replicas.gracePeriod: 900`.
- **Stateful/data resource impact:** none. This changes a Deployment spec field
  (`terminationGracePeriodSeconds`) and a ConfigMap value (`drainSeconds`) only — no PVC, no
  database schema, no migration, no data at rest.
- **Rollback:** revert the chart change (or, for FraudX, drop the values override). A chart with no
  `gracePeriod` set renders identically to pre-change behavior, so rollback is a plain
  `helm upgrade` back to the prior chart version/values — no data to unwind.
- **Roll-forward risk (once an install sets `gracePeriod`):** a pod that never drains cleanly
  (crashed rather than draining) now takes up to the configured `gracePeriod` (bounded, e.g. 900s
  in the FraudX override — not unbounded) to be force-killed on a scale-down or rollout, instead of
  today's 30s. This is the intended trade (give in-flight large documents time to finish) and is
  opt-in per install.
- Per `openspec/config.yaml`: no open design questions remain after consulting `AGENTS.md` and the
  existing specs/templates (the `celery.yaml:73-76` grace-period-render precedent and the
  `extract-supervisord-conf.yaml:15-16` margin-derivation precedent both already exist in this
  chart) — `superpowers:brainstorming` is not invoked; **none**.

## What Changes

- Add optional integer `replicas.gracePeriod` to the Go queue-service `replicas` schema blocks in
  `src/groundx/values.schema.json` — `summaryClient` (currently lines 1321-1330), `queue`
  (1143-1152), `process` (1103-1112), `preProcess` (1063-1072), `upload` (1361-1370) — keeping
  `additionalProperties: false` on each `replicas` block. (Precedent: the `extract.*` sub-service
  `replicas` blocks already carry `gracePeriod` as a plain integer, e.g.
  `values.schema.json:1424`.)
- In `src/groundx/templates/app/golang.yaml`, render `terminationGracePeriodSeconds` from the full
  `gracePeriod` value, guarded by `hasKey $rp "gracePeriod"` — mirrors the existing
  `templates/app/celery.yaml:73-76` pattern exactly (`$rp` — the per-service `replicas` map — is
  already read at `golang.yaml:23`). This applies to every service the shared `golang.yaml`
  template renders (all five Go queue services), since the template loops over all of them in one
  pass; the guard means only a service whose values set `gracePeriod` is affected.
- In `src/groundx/templates/resources/config-yaml.yaml`, render `drainSeconds` =
  `gracePeriod − ~30s margin` (precedent: `templates/resources/extract-supervisord-conf.yaml:15-16`,
  `int (dig "gracePeriod" 900 $replicas)` / `int (max 1 (sub $gracePeriod 30))`), gated on each
  service's own `replicas.gracePeriod` presence, at the **same YAML level as
  `baseURL`/`maxConcurrent`/`port`/`serviceName`** — in **all five** Go queue-service blocks:
  `preProcessFileServer` (`config-yaml.yaml:540-544`), `processFileServer` (`:546-550`),
  `queueFileServer` (`:575-580`), `summaryServer` (`:609-613`), `uploadFileServer` (`:635-639`).
  `config-yaml.yaml` renders these five blocks as five separately-authored literal stanzas, not
  through a `range` over `groundx.golang.services` (that `$svcs` variable, defined at line 1, is
  used only to gate the section as a whole at line 71 — confirmed by reading the file; there is no
  existing per-service loop to hook into for this section), so this is five parallel edits, one per
  block, each computing its own service's replicas dict via the service's existing
  `groundx.<svc>.replicas` helper (e.g. `groundx.preProcess.replicas`, already used the same way by
  `golang.yaml`'s per-service loop) and gating on `hasKey $rep "gracePeriod"` before emitting
  `drainSeconds` — see the code-grounding note below.
- Sync the `helm/` mirror (`helm/values.schema.json`, `helm/templates/app/golang.yaml`,
  `helm/templates/resources/config-yaml.yaml`) — verified byte-identical to their `src/groundx/`
  counterparts before this change, so the same edits apply 1:1.
- Regenerate the `helm-unittest` snapshots that cover the changed templates
  (`src/groundx/tests/__snapshot__/golang_test.yaml.snap`, covered by `tests/golang_test.yaml`;
  `src/groundx/tests/__snapshot__/resources_test.yaml.snap`, covered by `tests/resources_test.yaml`
  — confirmed it already exercises `templates/resources/config-yaml.yaml`).
- No **BREAKING** changes — additive schema property + additive template guard, default unset.

### Code-grounding note (corrected)

An earlier draft of this proposal scoped `drainSeconds` rendering to `summaryServer` only; that
premise was wrong. It read the FINALIZED contract text as scoping `drainSeconds` to
"the summaryClient queue-server block" and concluded the other four blocks had no reader for the
key, so rendering it there would be unused config (overbuild). Reading the actual cashbot-go
code (not just the contract prose) shows that premise was incorrect:

- `config.QueueServer` (`pkg/config/types.go:279`, fields `BaseURL`/`DrainSeconds`/
  `MaxConcurrent`/`PollTime`/`Port`/`ServiceName`) is **one shared struct type**, and the top-level
  `Config` embeds it five times — `PreProcessFileServer`, `ProcessFileServer`, `QueueFileServer`,
  `SummaryServer`, `UploadFileServer` (`pkg/config/api.go:76,79,127,141,147`) — each with its own
  `yaml:"..."` tag matching this chart's five `config-yaml.yaml` block names exactly.
- Each of the five Go binaries passes its own block into `server.NewQueueServer`:
  `server/PreProcessTrainFile/main.go:195` → `cfg.PreProcessFileServer`;
  `server/ProcessTrainFile/main.go:149` → `cfg.ProcessFileServer`;
  `server/QueueTrainFile/main.go:147` → `cfg.QueueFileServer`;
  `server/ProcessFiles/main.go:320` → `cfg.SummaryServer`;
  `server/FileUploadIngest/main.go:135` → `cfg.UploadFileServer`.
- The drain wait that actually reads the field — `q.Cfg.DrainSeconds` at
  `pkg/server/queue.go:344` and `:357` inside `processInfinite` — is the **one generic code path**
  all five binaries run through (`q.Cfg` is whichever `QueueServer` was passed in above).

So all five blocks read `DrainSeconds` today via the same shared mechanism; there is no
per-service reader gap. This proposal renders `drainSeconds` in all five `config-yaml.yaml`
blocks, gated per-service on `replicas.gracePeriod` presence (so an install that sets it only for
`summaryClient` still renders `drainSeconds` only for `summaryClient` — the four Go-only additions
before this point were never keyed to a different gate). Generic rendering (all five, same guard)
is chosen over a `summaryClient`-only render for two reasons: (1) it matches the code — each block
has a real, live-today reader, so rendering all five is not overbuild; and (2) it keeps this
proposal symmetric with the generic `terminationGracePeriodSeconds` render in `golang.yaml`, which
already applies uniformly to all five services because the shared template loops over all of
them — rendering `drainSeconds` narrower than that would be an inconsistent asymmetry with no
code reason behind it. It also keeps the deferred sizing follow-up (setting concrete
`gracePeriod`/`drainSeconds` values per service) a values-only change with no further template
work. The `gracePeriod` **schema** property and the `terminationGracePeriodSeconds` **k8s** render
were already scoped to all five Go queue services in the prior draft (per Ben's C6 comment and
because the shared `golang.yaml` template renders all of them in one pass) — that part is
unchanged.

## Capabilities

### New Capabilities
- `queue-service-grace-period`: the chart's ability to render a k8s termination grace period
  (`terminationGracePeriodSeconds`, from `replicas.gracePeriod`) and a matching application-level
  drain budget (`drainSeconds`) for **any of the five** Go queue-service pods
  (`summaryClient`/`process`/`upload`/`queue`/`preProcess`), so that an install can opt a service
  into cashbot-go's graceful-drain behavior without any chart default changing.

### Modified Capabilities
(none — no existing `openspec/specs/` capability covers Go queue-service replicas or config
rendering; this is new chart surface, not a change to previously-specified behavior.)

## Impact

- **Files:** `src/groundx/values.schema.json`, `src/groundx/templates/app/golang.yaml`,
  `src/groundx/templates/resources/config-yaml.yaml`, and their `helm/` mirror counterparts;
  `src/groundx/tests/__snapshot__/golang_test.yaml.snap`,
  `src/groundx/tests/__snapshot__/resources_test.yaml.snap`.
- **Dependencies:** none new — no chart dependency, Helm version, or backing-service change.
  Depends on the already-FINALIZED cashbot-go `drainSeconds-config` contract (cashbot-go ships the
  `DrainSeconds` field and drain logic; this repo only needs to be able to render the values).
- **Systems:** Kubernetes Deployment spec (`terminationGracePeriodSeconds`) and the app ConfigMap
  consumed by the five Go queue-service binaries (`drainSeconds`, one per
  `summaryClient`/`process`/`upload`/`queue`/`preProcess` block) — no other system.
- **Out of scope (unchanged by this proposal):** setting concrete chart-default `gracePeriod`
  values for any service; DLQ; HPA `scaleDown` tuning; raising the SQS visibility timeout. Sizing
  values (`gracePeriod: 900`/`drainSeconds: 870`) live in the private FraudX values override, a
  separate repo, not touched here.
