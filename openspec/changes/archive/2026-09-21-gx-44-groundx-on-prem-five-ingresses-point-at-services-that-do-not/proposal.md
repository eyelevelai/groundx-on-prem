# GX-44: Generated Ingress backends must name the rendered `-api` Service

- **Ticket**: GX-44
- **Author**: Dilip Dhankecha <dilip.dhankecha@smartsensesolutions.com>
- **Date**: 2026-09-21

## Why

The generated (pathless) Ingress for each of the five API components — extract, layout, ranker,
summary, workspace — names its backend Service from the component's base name (e.g. `layout`),
while the chart actually renders that Service as `<component>-api` (e.g. `layout-api`)
(`src/groundx/templates/resources/ingress.yaml:7,48,53`; each `*-api.tpl` helper's `name` comes
from the base `serviceName` helper while the Service itself is named via `printf "%s-api"`, e.g.
`src/groundx/templates/_helpers/app/layout-api.tpl:8-11` vs `:205`). The Ingress therefore points
at a Service the chart never creates, on both supported Ingress API shapes
(`networking.k8s.io/v1` and the legacy shape). `groundx` and `layoutWebhook` are unaffected by
this naming defect — their Ingress `name` already comes from the same `serviceName` helper as
their Service, so the two names already match. No deployment evidence of customer impact exists;
this is a latent misconfiguration in the generated backend reference, not an observed outage.

Separately, nothing today stops a pathless API Ingress from being enabled on a component that the
chart does not create — the Ingress renders naming a Service that will never exist, silently. The
guard added for this (see "What Changes") is scoped to the five `*.api` entries, so `groundx` and
`layoutWebhook` remain able to render this way — `layoutWebhook` because the suffix gate skips it,
`groundx` because it never enters the guarded loop at all. A known, deferred gap (see `tasks.md`
"Deferred follow-ups").

## What Changes

- Derive the generated Ingress backend name from each entry's `-api` Service helper
  (`groundx.<entry>.serviceName`) at one site in `resources/ingress.yaml`, alongside the existing
  `$port` derivation, and use it at both backend sites (the `networking.k8s.io/v1` shape and the
  legacy shape). The Ingress object's own `name` is unchanged, so existing Ingresses upgrade in
  place — no recreate.
- **BREAKING** (one configuration, by design): a pathless API Ingress enabled while its component is
  not created now fails the template render instead of rendering a dangling backend — scoped to the
  five API entries, and only the pathless case (a custom `ingress.paths` block is user-managed and
  already unaffected by this change).
- Mirror both changed template files into `helm/` (today byte-identical to `src/groundx/` for these
  two files — verified by `diff`).

### Explicitly out of scope

Narrowed at the brainstorm gate (Benjamin Fletcher, 2026-09-11) to the pathless generated-Ingress
backend behavior only. Routed to separate tickets, not addressed here:
- The file Ingress never rendering (`groundx.file.ingress` returns the wrong shape).
- `ai.eyelevelSearch` being emitted unconditionally regardless of whether ranker renders.
- The pre-existing `src/groundx` vs `helm/` mirror drift (verified absent on `main` for the two
  files this change touches; the known drift is on the `origin/0.2.7` line).
- `_helpers/app/ranker-inference.tpl:142` is a hard do-not-touch guardrail (Nitin Vavdiya,
  2026-09-15) and is untouched by this change.

The deliberate breaking configuration is an API Ingress enabled on a component that is not created
(e.g. `extract.api.ingress.enabled: true` without `extract.enabled: true`) — not ranker under
`mode: ingest`, which was checked and found impossible: the chart's own `values.yaml` ships
`ranker.api.enabled: true`, so `ranker-api.tpl`'s explicit-key branch always wins over the
ingest-only default.

## Capabilities

### New Capabilities
- `ingress-backend-routing`: the generated (pathless) API Ingress must name the Service the chart
  actually renders, on both supported Ingress API shapes, and must fail template rendering rather
  than render a dangling backend when that Service is not created. No existing spec in
  `openspec/specs/` covers Ingress behavior.

### Modified Capabilities
(none)

## Impact

**Blast radius**: `src/groundx/templates/resources/ingress.yaml`,
`src/groundx/templates/_helpers/app/ingress.tpl`, their `helm/` mirrors, one regenerated
helm-unittest snapshot, new unit-test cases, and one new render assertion in
`.build/bin/validate-helm.sh`. No values schema change, no `*-api.tpl` helper change, no change to
Service/Deployment templates. Template-rendering only — no controller, Service, or stateful
resource behavior changes; nothing here touches data stores, migrations, or secrets.

**Affected environments**: every environment that deploys this chart (dev/staging/prod, any
self-hosted cluster) is affected at its *next* `helm upgrade` — this is a chart-source change, not
an already-running-cluster change, so nothing redeploys until an operator runs `helm upgrade`.

**Rollout**: in place. Ingress object names are unchanged, so `helm upgrade` patches existing
Ingress objects rather than recreating them; only the backend reference inside each Ingress moves
to the correct Service name. The one behavior change an operator can hit is the new hard-fail: an
install with a pathless API Ingress enabled on a component it does not create will stop rendering
until the operator drops that Ingress or enables the component — a release note, not a flag.

**Rollback**: revert the two template files (and their mirror) and re-render; no stateful resource
or data is touched by either direction, so rollback is a plain chart revert.

**Open design questions**: none — the fix shape (one-site derivation vs. the ticket's per-helper
`backendName` key) and the D4 hard-fail scope were resolved at the plan gate; see design.md.
