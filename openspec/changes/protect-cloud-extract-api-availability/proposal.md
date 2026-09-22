# Protect API availability during voluntary disruption

The hosted EKS deployment runs one `extract-api` replica. A voluntary node drain can therefore remove the only serving endpoint until Kubernetes schedules and readies a replacement.

Expose the same opt-in disruption-budget contract for `groundx`, `extract-api`, `layout-api`, `ranker-api`, `summary-api`, and `workspace-api`. Enable it in hosted EKS only for `extract-api`, after raising its desired and minimum counts to two. `ranker-api` settings are present in that values file but `mode: ingest` suppresses the workload. Generic and on-prem defaults remain unchanged.

This changes no stateful resource or customer data. It adds one small `extract-api` pod and one policy object in hosted production. Rollback restores the extract replica counts to one and disables the hosted budget. A budget can delay a voluntary node drain when Kubernetes cannot keep one replica available.

Affected environments: hosted production EKS only when the updated values are deployed. Open questions: none.
