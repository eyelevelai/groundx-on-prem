# Verification

Review PR: [chart #108](https://github.com/eyelevelai/groundx-on-prem/pull/108),
dependent on [Cashbot #1754](https://github.com/EyeLevel-ai/cashbot-go/pull/1754).
CI was pending when the PRs were opened. Keep this change active until merge.

The local chart gate passed on September 16, 2026: 319 source-chart tests and
850 snapshots, published-mirror and prerequisite suites, credential rendering,
workspace and storage contracts, syntax and whitespace checks. The new hook is
identical in the source and published mirror and both upgrade renders pass.

Existing Go service and resource suites cover fresh installs, external databases,
OpenShift, worker-only and disabled workloads, image overrides, scheduling,
security, credentials and service isolation. Existing snapshot payloads remain
unchanged. Independent chart review found no material issue.

No live Helm upgrade, image publication, database migration or customer recovery
has been performed. The compatible Cashbot image must be available before this
chart is deployed. CI results and deployed behavior are separate release gates.
