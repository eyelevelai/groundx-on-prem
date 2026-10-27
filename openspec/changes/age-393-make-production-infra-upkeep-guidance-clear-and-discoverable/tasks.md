## 1. AGENTS.md pointer

- [ ] 1.1 Add the approved pointer bullet under `## Agent boundaries` directly after the `terraform/aws/` bullet in `AGENTS.md`, scoped to GroundX hosted production, with no ticket id, internal link, account id, or ARN
  check: grep -qF "Never change GroundX hosted production AWS by hand" AGENTS.md && grep -qF "groundx-production-infra" AGENTS.md && git diff --check

See workspace `openspec/changes/age-393-make-production-infra-upkeep-guidance-clear-and-discoverable/tasks.md` for cross-service coordination and deferred items.
