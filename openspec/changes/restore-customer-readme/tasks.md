## Implementation

- [x] Compare the baseline and current README section by section. Preserve baseline wording/order and identify necessary current factual updates and useful later detail.
- [x] Rework the README from that baseline, keeping the current minimal starter and existing-install upgrade protections. Do not restore old invalid keys, insecure examples or obsolete service instructions.
- [x] Relocate detailed upgrades, Workspace, extraction diagnostics and EKS maintenance to the existing owner or the topic destinations in the design. Preserve unique information, warnings, ordering and rollback steps; add short README links.
- [x] Update inbound links, retain useful old heading pointers, and align location-specific OpenSpec requirements with the actual owning guide. Keep existing docs paths unless a move is necessary.
- [x] Add concise reciprocal maintenance guidance to the on-prem repository guide and the Harness on-prem maintenance reference. Update affected Harness references, examples and source links; do not add synchronization machinery or mandatory paired PRs.
- [x] Review the result as a first-time installer, existing customer upgrading and reader following an old link. Compare wording and section coverage against both historical and current READMEs.
- [x] Run link/anchor checks, source checks for changed commands and claims, strict OpenSpec validation and diff whitespace checks. Run an existing sample render if examples change; run existing Harness validation with the exact on-prem ref and refresh/check generated bundles when Harness source changes.
- [x] Present the documentation diff for review. Report preserved content, necessary factual updates and any unresolved owner-supplied claim separately from live deployment evidence. Do not deploy or publish a chart.

## Validation

- Preserved every existing README heading and verified 194 local documentation links and anchors.
- Retained 42 of 47 original fenced examples unchanged across the README and linked guides; the five changed blocks are list formatting, a generic values-file path, API readiness, and corrected HTTPS Python/TypeScript examples.
- Python and TypeScript quick-start examples parse. Both source and published Workspace chart contract checks pass, including the PVC behavior described in the guide.
- Strict OpenSpec validation passes for all 53 items. The Harness validation, including the chart-backed on-prem scan, passes against this checkout; generated internal/public bundles match.
- Independent review is clean after restoring the original OpenSearch numbered procedure and aligning the S4 guide ownership scenario.
- Historical product claims and the Open Beta label are retained from the baseline, without asserting a newly verified lifecycle status. No live deployment or backend acceptance was performed.
