## Goals / Non-Goals

**Goals:**
- Make the generated (pathless) Ingress for the five API components name the Service the chart
  actually renders, on both supported Ingress API shapes, per `proposal.md`.
- Make a pathless API Ingress fail template rendering rather than silently name a Service that is
  never created.

**Non-Goals:**
- The file Ingress never rendering, the unconditional `ai.eyelevelSearch.baseURL`, and the
  pre-existing `src/groundx` vs `helm/` drift on the `origin/0.2.7` line — all routed to separate
  tickets at the brainstorm gate (see `proposal.md` "Explicitly out of scope").
- Any change to `values.schema.json` or any `*-api.tpl` helper.

## Decisions

- **Invariant (gate class — this change adds a template-render guard):** a pathless API Ingress
  may render only when the Service it names is actually created by the chart. Everything below is
  in service of that one property, checked at the two sites where it can be violated (a wrong
  backend name, or a backend that is never created).

- **Backend derivation site.** `src/groundx/templates/resources/ingress.yaml` gains one new
  variable beside the existing `$portKey`/`$port` derivation (:18-19):
  ```
  {{- $backendKey := printf "groundx.%s.serviceName" $entry -}}
  {{- $backend := include $backendKey $ -}}
  ```
  `$backend` replaces `$name` at the two backend sites only — `service.name` in the
  `networking.k8s.io/v1` shape (:48) and `serviceName` in the legacy shape (:53). `metadata.name`
  (:26) keeps using `$name`, so the Ingress object's identity is unchanged and `helm upgrade`
  patches in place. No `*-api.tpl` helper changes; `groundx.<entry>.serviceName` already returns
  the rendered `-api` Service name for all five entries and is unaffected by this naming defect
  for `groundx` / `layoutWebhook` — their Ingress `name` already comes from that same
  `serviceName` helper, so it already matches their Service name (confirmed by render, see
  `proposal.md`).

- **Hard-fail (D4) site and scope.** The guard lives in
  `src/groundx/templates/_helpers/app/ingress.tpl`'s `groundx.app.ingress` entry loop, gated on
  `hasSuffix ".api" $svc`, so it evaluates only for the five literal `*.api` entries already in
  that loop's `$services` list (`extract.api`, `layout.api`, `ranker.api`, `summary.api`,
  `workspace.api`). Two entries can still render a pathless Ingress naming a Service the chart
  does not create, by two different routes: `layoutWebhook` is in the loop but is not a `*.api`
  entry, so the suffix gate skips it; `groundx` never enters the loop at all — it is set into
  `$svcs` by the pre-loop block at `ingress.tpl:5-9`, so widening the suffix gate would not reach
  it. Reproduce either with `--set <entry>.enabled=false --set <entry>.ingress.enabled=true` and
  checking no matching Service renders. `file` is in the loop and also not `*.api`; its
  ingress behaviour is tracked separately as its own deferred item.
  This is a deliberately narrow scope, deferred rather than fixed here (see `tasks.md`
  "Deferred follow-ups"), not an oversight. For each `*.api` entry, when its ingress is enabled
  **and** its `ingress.data` carries no non-empty `paths` (the pathless branch only — a non-empty
  `paths` block is user-managed and already renders its own backend, so there is nothing for this
  guard to judge), the loop calls `include (printf "groundx.%s.create" $entry) $`; when that
  returns `"false"`, the template fails:
  ```
  {{- fail (printf "%s.ingress is enabled but %s is not created; enable %s or remove the ingress" $svc $svc $svc) -}}
  ```
  This message is the contract for the `failedTemplate` test case in `tests/ingress-guard_test.yaml`
  — the exact string must match on both sides (test and template) since it is the only thing the
  test asserts against.

- **Mirror.** Both changed files (`resources/ingress.yaml`, `_helpers/app/ingress.tpl`) are
  mirrored byte-for-byte into `helm/` — confirmed byte-identical to `src/groundx/` today (`diff
  -q`), so the mirror step is a plain copy, not a merge.

- **Test layout (decided during this authoring pass, not fully pinned by the ticket/proposal):**
  three narrowly-scoped files keep each RED check meaningful on its own:
  - `tests/workspace_test.yaml`'s existing "enabled: workspace api ingress" case gains one `equal`
    assertion on the backend name, ahead of its `matchSnapshot`. The snapshot itself is
    regenerated once the fix lands (`helm unittest -u src/groundx`) — the flip from `workspace` to
    `workspace-api` in that snapshot is the primary observable proof of the fix.
  - `tests/ingress_test.yaml` (new) carries only the legacy-`apiVersion` case — independently RED,
    since it needs no D4 code to demonstrate the backend-name defect on the second shape.
  - `tests/ingress-guard_test.yaml` (new) carries the D4 pair (`catches` + `must not block`)
    together, because the must-not-block case alone renders successfully both before and after
    D4 exists (nothing yet blocks it) — bundling it with the `catches` case in one suite file means
    the whole-file run stays RED pre-implementation (the `catches` case's `failedTemplate`
    assertion fails until D4 lands) and only goes GREEN once both are correct.
  - `.build/bin/validate-helm.sh` gets a standalone render-and-grep assertion beside the existing
    `extract-agent` image-settings block (:80-85) proving both `src/groundx` and `helm` name
    `extract-api`/`summary-api` for `tests/files/values.phoenix.yaml`, and one
    `expect_helm_template_failure` call inside the existing both-surface loop (:80-85) for
    `--set workspace.api.ingress.enabled=true` against `values/extract/values.yaml` (a verified
    trigger: `workspace.api.create` is false there). This is the only D4 coverage on the `helm`
    surface, since `helm unittest` runs `src/groundx` only.

## Risks / Trade-offs

- [Risk] The `fail` message is matched verbatim by a test — a future wording edit silently breaks
  `tests/ingress-guard_test.yaml` → Mitigation: the message lives in exactly one template line and
  one test assertion; `tasks.md` keeps them in the same task.
- [Risk] `helm-unittest` has no per-case filter, so `tests/ingress-guard_test.yaml`'s two cases
  share one `check:` command → Mitigation: documented above; both cases are read together at
  review, and the file's own `it` names distinguish them in output.
