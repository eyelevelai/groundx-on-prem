## 1. AGENTS.md pointer

- [x] 1.1 Add the approved pointer bullet under `## Agent boundaries` directly after the `terraform/aws/` bullet in `AGENTS.md`, scoped to GroundX hosted production, with no ticket id, internal link, account id, or ARN
  check: grep -qF "Never change GroundX hosted production AWS by hand" AGENTS.md && grep -qF "groundx-production-infra" AGENTS.md && git diff --check

Cross-service coordination and deferred items are in the engineering-context repo, `openspec/changes/archive/2026-10-27-age-393-make-production-infra-upkeep-guidance-clear-and-discoverable/tasks.md` (EyeLevel-ai/engineering-context#218).
