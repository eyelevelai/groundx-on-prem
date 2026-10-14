# Related repository changes

Change ID: protect-hosted-file-access. Change directory in every owner: openspec/changes/protect-hosted-file-access. Working branch for planning and implementation in every owner: plan/protect-hosted-file-access.

Publication status: local revised drafts, not pushed PRs. Repository links below identify actual remotes; they do not imply these change files are published. Before implementation handoff, publish the existing working branches as draft PRs for design review, add actual PR URLs here, and replace handoff source identities with reviewed commit SHAs. Do not link to a nonexistent published plan or treat structural validation as review.

## Branch and PR lifecycle

Each repository uses one existing working branch, plan/protect-hosted-file-access, for both planning and implementation. The plan prefix is part of the existing branch name, not a separate planning workflow. Keep the same checkout and branch after design review; append implementation, tests and OpenSpec updates there. Do not create a second implementation branch or cherry-pick the plan onto another branch.

Open one draft PR per repository from that working branch. Review the proposed design while it is a draft, then add implementation commits to the same PR. Do not merge a planning-only PR to start a separate implementation PR. Update the PR title/body to describe the final delivered behavior, and mark it ready only when its repository's implementation and required validation are complete. Cross-repository release gates and production approvals remain independent of branch/PR continuity.

## cashbot-go

Repository: [cashbot-go](https://github.com/EyeLevel-ai/cashbot-go). Base branch: master, pushed baseline 041dc06a536b8e79a6ac5b72ce3968b431db5df3. Proposed plan: openspec/changes/protect-hosted-file-access/design.md. Publication: pending.

## eyelevel-fern-config

Repository: [eyelevel-fern-config](https://github.com/eyelevelai/eyelevel-fern-config). Base branch: main, pushed baseline bf3d69c47e192eb89d876e9ff1e82ec2c621b549. Proposed plan: openspec/changes/protect-hosted-file-access/design.md. The Fern producer also owns contract.md and contract.schema.json. Publication: pending.

## groundx-on-prem

Repository: [groundx-on-prem](https://github.com/eyelevelai/groundx-on-prem). Base branch: main, pushed baseline 07d332fc6cde11e3e1ce1247f0ac41a16708570a. Proposed plan: openspec/changes/protect-hosted-file-access/design.md. Publication: pending.

## ai-server

Repository: [ai-server](https://github.com/EyeLevel-ai/ai-server). Base branch: master, pushed baseline d7a174d1635870b75d5e84787c696d7c7d471b8b. Proposed plan: openspec/changes/protect-hosted-file-access/design.md. Publication: pending.

## groundx-production-infra

Repository: [groundx-production-infra](https://github.com/EyeLevel-ai/groundx-production-infra). Base branch: main, pushed baseline fe01f0cd1de6b4f83d380017858881724c402dcb. Proposed plan: openspec/changes/protect-hosted-file-access/design.md. Publication: pending.

## Consumer responsibilities

Cashbot owns shared runtime, policy/caches/gateway and source bindings. Fern owns resource/link/upload contracts and SDK/doc propagation. Helm owns local configuration/routing and independent vendor support gates. ai-server owns private local initialization/client endpoint. Production infrastructure owns cloud adoption/routing/private-origin enforcement. Dashboard/middleware/SDK/Harness compatibility tasks remain in Cashbot/Fern; no unrelated runtime change is part of these plans.
