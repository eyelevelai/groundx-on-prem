## Decision

The production cluster's Terraform `cluster_addons` map owns `amazon-cloudwatch-observability`. Add a default-off Terraform input there. When enabled, set `agents` to the existing `cloudwatch-agent` with no overrides plus one deployment-mode agent that only collects CoreDNS Prometheus metrics. This avoids replacing Container Insights or Application Signals and avoids duplicate scrapes from a DaemonSet on every node. Discover only kube-system CoreDNS pods and label each sample by pod. Pin the currently installed add-on version before rollout.

Add the probe as an optional sidecar in `extract-agent`, reusing that pod's node placement, service account, network, and resolver. Its target hostname comes from the chart's `groundx.cache.addr` helper. A separate DaemonSet cannot cover production extraction workers: the affected CPU node has its full allotment of 17 pods. The sidecar adds no pod slot. On failed or slow lookup, it asks the Kubernetes API for kube-dns EndpointSlices via the API service IP and directly queries every listed backend over UDP. Readiness is captured before direct query so a failing but still-ready backend is visible. A namespace-scoped Role and RoleBinding permit only EndpointSlice listing. The probe makes no changes to EndpointSlices, CoreDNS, Redis, or extraction.

The probes log each failure or slow lookup with node, target, elapsed time, endpoint readiness, and direct-query results. Resolver errors appear only on failures. Successful checks are summarized periodically. CoreDNS metrics and probe logs together can distinguish a backend failure, EndpointSlice lag, and a node-local DNS service-path problem. CloudWatch's Prometheus processor drops CoreDNS duration histograms, so the probe supplies worker-observed lookup duration. These signals cannot by themselves prove the underlying host failure cause; NodeDiagnostic remains the host evidence path.

## Rollout

1. Validate Terraform input and rendered chart locally. Fault-test the probe locally with a ready but nonresponsive DNS server and a responsive server.
2. Review a production Terraform plan showing only the CloudWatch add-on configuration change. Confirm the existing agent still has its default config and the new collector is one deployment.
3. Apply the Terraform change, wait for the new collector, and confirm separate CoreDNS samples reach CloudWatch. This step is complete.
4. Compare the installed GroundX release with the sidecar-enabled chart using its live values. Stop on unrelated changes. Use `--reset-then-reuse-values` so the probe's new image and resource defaults are present. Set `extract.agent.rolloutStrategy` to `maxSurge: 1` and `maxUnavailable: 0` with capacity or autoscaling headroom. Preserve the current CPU node affinity and add required pod anti-affinity so the two worker replicas land on different nodes. Check current worker tasks and the 32Mi per-pod memory request before the restart. Roll out the Helm change only after this gate, wait for two ready workers, and confirm sidecar logs from both. The production rollout is complete at Helm revision 399; its live chart was extended without adopting unrelated repository-chart differences.
5. Observe a real incident. Do not inject DNS failures in production. A live fault exercise needs a separately authorized disposable EKS cluster with the same add-on version and node topology.

## Rollback

Disable `extract.agent.dnsProbe.enabled` and roll the extraction pods back while retaining their placement and safe rollout strategy. Disable `dns_observability.enabled` and apply a reviewed Terraform plan to remove the dedicated collector, without changing the existing CloudWatch agent. Historical CloudWatch records remain subject to existing retention.
