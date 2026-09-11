# Implementation evidence

The implementation uses pushed baseline `origin/0.2.7` at
`b8e57f2dd44f96e5486c1537d3c243e5fb47d087`. The matching cashbot-go worker is
implemented in `f3f89529f`, with the shared queue/server config in `57d83de4c`.
The delivery container build is `server/SummaryBillDeliver/Dockerfile.summary-bill-delivery`.
The producer container includes `/app/summary-bill-pdf-count`.

The optional service, explicit image/resources, credential mounts, and Kafka/SQS
transport are implemented in canonical `src/groundx` and mirrored to `helm`.
The [operator guide](../../../docs/agents/summary-bill-delivery.md) describes the
exact configuration and activation boundary. Account policy remains outside the
chart; enabling the worker does not enable any account.

## Engineering checks

Verified on 2026-09-11:

- `.build/bin/validate-helm.sh`: passed the full `0.2.7` production gate,
  including 14 suites, 282 tests and 815 snapshots, plus the additional nine
  selected checks. The gate prepares and removes its required OCR fixture,
  validates both chart surfaces, workspace/storage contracts and render checks.
  Seven new assertions/scenarios cover the delivery worker, mounted secrets,
  shared config, disabled behavior, Kafka partitions, SQS selection and
  producer credential isolation. Existing snapshots were not regenerated.
- `helm lint src/groundx`: passed; only the existing optional icon suggestion.
- `helm template local src/groundx -f src/groundx/values/minikube/values.yaml`: passed.
- Disabled and explicitly disabled source rendering compared byte-for-byte with
  pushed `0.2.7`, including workload configuration hashes: identical.
- Enabled and disabled source/mirror renders match with identical chart metadata
  and values. The target branch already has different source/mirror chart versions
  and one extract-download memory default; those unrelated defaults are unchanged.
- `git diff --no-index src/groundx/templates helm/templates`: identical.
- `git diff --check`: passed.
- In the matching cashbot-go worktree:
  `SUMMARY_BILL_CHART_PATH=<absolute-src/groundx> go test -tags groundx_chart_integration ./pkg/config -run '^TestSummaryBillChartConfiguration$' -count=1`
  passed in 3.008s. It decodes actual Kafka/SQS renders using runtime configuration types,
  reads the `0.2.7` Secret `stringData` configuration, verifies the shared queue,
  credentials and budgets, tests disablement, and
  rejects invalid image, concurrency, byte/time budgets, secret bindings and
  missing resource limits through the chart schema.

The enabled fixture contains a test image, synthetic budgets and Secret
names; it is not an operational configuration.

## Activation boundary

No image publication, cluster mutation, account change, production migration or
Drive upload was performed. Live worker capacity, Shared drive authorization,
queue visibility/retention, image availability, deployed schema compatibility,
replacement of old producers and customer completion semantics remain governed
by the cashbot-go activation record. These checks gate activation, not local
implementation. Independent review of the feature found no unresolved major
findings. Release-branch integration preserves its Secret-based config and
volume mounts; validation above covers the resulting `0.2.7` candidate.
