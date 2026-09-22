# Protect cloud extract API availability

The hosted EKS deployment runs one `extract-api` replica. A voluntary node drain can therefore remove the only serving endpoint until Kubernetes schedules and readies a replacement.

Add an opt-in extract API disruption budget to the chart, then enable it only in the hosted EKS values with two desired and minimum replicas. Generic and on-prem defaults remain unchanged. This changes no stateful resource or customer data. It rolls only `extract-api` when deployed and adds one small API pod in hosted production.

Rollback restores the hosted replica counts to one and disables the budget. A budget can delay a voluntary node drain when Kubernetes cannot keep one replica available.

Affected environments: hosted production EKS only when the updated values are deployed. Open questions: none.
