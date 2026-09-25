See `proposal.md` for the motivation and blast radius. This is a schema-only widening of an
existing, already-shipped (GX-20) render surface — there is no template, helper, or Kubernetes
object change, so no new architectural decision or ADR is warranted.

## Goals / Non-Goals

**Goals:**
- Let an operator set `cognito.mode: local` and have it pass schema validation and render.
- Prove, with an executable check, that the render is unaffected for every other accepted value
  and for installs that never set `cognito.mode`.

**Non-Goals:**
- Implementing or documenting the local password-login *flow* itself (register/login/reset) —
  that behavior lives entirely in cashbot-go's runtime and is out of this chart repo's scope.
- Any change to the four Cognito-specific keys (`clientId`/`clientSecret`/`poolId`/`region`) or
  to the block-level/per-key render guards GX-20 already built — `local` needs none of them.
- Validating which cashbot-go image version supports `local` — the chart accepts the string and
  does not gate on image version, matching its existing behavior for `cognito`/`apiKeyOnly`.

## Decisions

- **Widen the existing enum rather than relax it to a free-form string.** GX-20's review-fix
  round 1 (see `openspec/changes/archive/2026-09-15-gx-20-.../design.md` Amendments) deliberately
  added the `enum` constraint (see
  `openspec/changes/archive/2026-09-15-gx-20-on-prem-has-no-identity-provider-servergroundx-wires-a-mock/tasks.md`
  task 1.3 and its Amendments) so a typo'd `cognito.mode` value fails at `helm template`/`helm
  lint` time instead of silently reaching cashbot-go's tolerant-reader fallback. Dropping the
  enum back to `"type": "string"` to accommodate `local` would undo that fix for every value, not
  just add one. Adding `"local"` to the enum keeps the typo guard for every other value while
  accepting the one new one.
- **No template/helper change.** The existing `groundx.cognito.mode` helper
  (`templates/_helpers/main.tpl`) and the `mode: {{ include "groundx.cognito.mode" . | quote }}`
  render (`templates/resources/config-yaml.yaml`) already pass through whatever string
  `cognito.mode` resolves to, quoted. Confirmed by direct render
  (`helm template … --set cognito.mode=local`): `cognito:\n  mode: "local"` renders with zero
  code changes beyond the schema enum. Re-deriving this render path (as a from-scratch main-based
  branch would need to, absent GX-20's seam) would duplicate what already exists here.
- **Mirror `values.schema.json` byte-for-byte into `helm/`, same as every prior chart-contract
  change in this repo.** No mirror-check gate enforces schema.json specifically today (see
  `docs/agents/*`/`AGENTS.md` "no general drift check between helm/ and src/"), so this is
  confirmed manually via `diff -q` per task, not by an automated gate.

## Risks / Trade-offs

- [Risk] An operator sets `cognito.mode: local` against a cashbot-go image that predates local
  password-login support → cashbot-go's own startup validation is what rejects/degrades this, not
  the chart (matches the existing `cognito` mode's division of responsibility — the chart never
  validates cross-service semantic compatibility). Mitigation: documented in
  `docs/on-prem-identity.md` and `README.md` as an explicit precondition.
- [Risk] Rolling back to a pre-this-change chart version for an install that set `cognito.mode:
  local` → schema validation rejects the render (`helm template`/`helm upgrade` failure), not a
  silent fallback. Mitigation: documented in `docs/on-prem-identity.md`'s Rollback section — roll
  forward, not back, for such an install.

## Migration Plan

No stateful resource, no new Kubernetes object, no migration. Rollout is a normal chart-version
bump: an install that does not set `cognito.mode` (or sets it to `cognito`/`apiKeyOnly`) is
byte-for-byte unaffected; an install that sets `cognito.mode: local` requires pairing with a
cashbot-go image that supports it, in either deploy order (the chart change is inert until the
value is set). No canary/stage-then-prod sequencing beyond the repo's normal PR → merge → publish
flow; no manual ops or secret changes.

## Open Questions

None.
