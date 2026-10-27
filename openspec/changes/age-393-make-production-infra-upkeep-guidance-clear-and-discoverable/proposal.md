## Why

Changes to GroundX hosted production AWS can be made by hand without being recorded anywhere durable. An agent or engineer working in this repo is pointed at `terraform/aws/` for AWS infrastructure and has no signal that hosted production AWS changes are meant to be recorded in `groundx-production-infra`.
## What Changes

- Add one bullet to `AGENTS.md` under `## Agent boundaries`, directly after the `terraform/aws/` bullet, carrying a one-sentence pointer: never change GroundX hosted production AWS by hand; record every change in `groundx-production-infra` in the same change, adding the resource if it is missing; adoption is partial, so apply through whatever currently manages the resource.
- Scope the bullet to GroundX hosted production only, so it neither contradicts nor implies retirement of `terraform/aws/`, which customers continue to run on their own AWS.
- Documentation only. No chart, template, values, script, Terraform, or `helm/` mirror change. No account IDs or ARNs, no ticket ids, no internal links; the bullet names `groundx-production-infra` as the record.

Blast radius: none at runtime. No environment or cluster redeploys, no stateful resource is touched, and `AGENTS.md` is not rendered into any chart. Rollback is reverting the single bullet.

Open design questions: none.

## Capabilities

### New Capabilities
<!-- none: documentation-only change, no spec-level behavior -->

### Modified Capabilities
<!-- none -->

## Impact

- `AGENTS.md` (one added bullet). No other file is touched.
- Readers: agents and engineers working in `groundx-on-prem`. Public repo, so wording must stay free of internal links and account details.
- Gate: the only check that applies to this change is `git diff --check` (whitespace), run by `.build/bin/validate-helm.sh`; the bullet must not introduce a whitespace failure.
