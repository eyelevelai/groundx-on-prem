## Implementation

- [ ] Compare the baseline and current README section by section. Preserve baseline wording/order and identify necessary current factual updates and useful later detail.
- [ ] Rework the README from that baseline, keeping the current minimal starter and existing-install upgrade protections. Do not restore old invalid keys, insecure examples or obsolete service instructions.
- [ ] Relocate detailed upgrades, Workspace, extraction diagnostics and EKS maintenance to the existing owner or the topic destinations in the design. Preserve unique information, warnings, ordering and rollback steps; add short README links.
- [ ] Update inbound links, retain useful old heading pointers, and align location-specific OpenSpec requirements with the actual owning guide. Keep existing docs paths unless a move is necessary.
- [ ] Add concise reciprocal maintenance guidance to the on-prem repository guide and the Harness on-prem maintenance reference. Update affected Harness references, examples and source links; do not add synchronization machinery or mandatory paired PRs.
- [ ] Review the result as a first-time installer, existing customer upgrading and reader following an old link. Compare wording and section coverage against both historical and current READMEs.
- [ ] Run link/anchor checks, source checks for changed commands and claims, strict OpenSpec validation and diff whitespace checks. Run an existing sample render if examples change; run existing Harness validation with the exact on-prem ref and refresh/check generated bundles when Harness source changes.
- [ ] Present the documentation diff for review. Report preserved content, necessary factual updates and any unresolved owner-supplied claim separately from live deployment evidence. Do not deploy or publish a chart.
