## Goals / Non-Goals

Goal: add the approved one-sentence pointer to `AGENTS.md` (see `proposal.md`). Non-goals: any change to `terraform/aws/`, README, chart, values, scripts, or `helm/`.

## Decisions

1. **One bullet, placed directly after the `terraform/aws/` bullet** under `## Agent boundaries`, so a reader who lands on the Terraform guidance sees the production pointer next. Wording is the approved sentence: "Never change GroundX hosted production AWS by hand: record every change in `groundx-production-infra` in the same change, adding the resource if it is missing. Adoption is partial, so apply through whatever currently manages the resource."
2. **Scoped to GroundX hosted production.** The existing `terraform/aws/` bullet and the `eks-cluster-version-config` requirement "`terraform/aws/`'s supported status is documented consistently" stay true; the new bullet adds no claim about customer-run AWS.
3. **Minimum specs delta.** The schema blocks `tasks` until a specs artifact exists, so one ADDED requirement with two scenarios is added to the existing `eks-cluster-version-config` capability, which already governs how `AGENTS.md` describes `terraform/aws/`. No new capability is created.
4. **No other mechanism.** No script, lint, or CI check is added; the only gate that applies is `git diff --check`, which `.build/bin/validate-helm.sh` runs, and the acceptance check below.

No ADR is warranted. No cross-service contract: `contract.md` shapes are not touched.
