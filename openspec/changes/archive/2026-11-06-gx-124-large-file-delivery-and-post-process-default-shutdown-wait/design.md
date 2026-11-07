## Goals / Non-Goals

**Goals:**
- An enabled `largeFileDeliver` or `postProcess` worker renders the same 900/870 default as the five always-rendered Go queue services, and an explicit `replicas.gracePeriod` wins.
- `src/groundx` and `helm/` render identically.

**Non-Goals:**
- cashbot-go drain logic, the autoscaler cap, hosted Lambda behavior, per-worker tuning from measured job durations.

## Decisions

**Invariant:** a Go queue service's rendered grace-period fields equal its own explicit `replicas.gracePeriod` when set and 900/870 when not, never another service's value.

1. Set the default in each worker's own `replicas` helper with `dig "replicas" "gracePeriod" 900`, the form those helpers already use for `desired`, so the unchanged `hasKey` guard in `app/golang.yaml` renders `terminationGracePeriodSeconds`. The five services use a longer `hasKey` and `set` form because their helpers merge a full dict; these two helpers emit only `desired`.
2. Render `drainSeconds` in each worker's own config helper from that worker's helper value (`get ... "gracePeriod"`), so it can never take another block's value. Readers of the two replicas helpers other than `app/golang.yaml` (`services/topics.tpl`) read only `desired`.
3. Schema: add `gracePeriod` to both `replicas` blocks, keeping `additionalProperties: false`.
4. Snapshots: only the six entries that render an enabled worker change (config-hash lines on every Deployment, one `terminationGracePeriodSeconds: 900`, one `drainSeconds: 870` per enabled render). They are hand-patched and verified by `helm unittest` without `-u`.

Producer contract shapes: none; INDEPENDENT chart change. The cashbot-go config type behind both blocks already has `drainSeconds` (`config.QueueServer`).

## Risks / Rollout

- Blast radius: installs with a worker enabled roll every `golang.yaml` Deployment once. Installs with both off render identically.
- 900 seconds is the GX-124 assumption for the five services; no job duration was found for `postProcess`, and `largeFileDeliver` uploads are bounded by an operator-set `maxUploadDuration`.
- Rollback: revert the change.
- Verified by `helm unittest` and the `validate-helm.sh` gate, which also byte-compares `src/groundx/templates` against `helm/templates`.
