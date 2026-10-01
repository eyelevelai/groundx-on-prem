## Decision

The production cluster's Terraform `cluster_addons` map owns `amazon-cloudwatch-observability`. Add a default-off Terraform input there. When enabled, set `agents` to the existing `cloudwatch-agent` with no overrides plus one deployment-mode agent that only collects CoreDNS Prometheus metrics. This avoids replacing Container Insights or Application Signals and avoids duplicate scrapes from a DaemonSet on every node. Discover only kube-system CoreDNS pods and label each sample by pod. Pin the currently installed add-on version before rollout.

Use a separate Helm chart under `monitoring/dns-probe` for the probe. Its `targetHost` comes from the current GroundX Helm `cache.existing.addr`, not a copied constant. It runs on nodes selected the same way as `extract-agent`, including the legacy `node` label and current `eyelevel_node` label, with matching NoSchedule tolerations. It uses the pod's normal resolver first. If that lookup fails or takes more than two seconds, it asks the Kubernetes API for kube-dns EndpointSlices via the API service IP and directly queries every listed backend over UDP. Readiness is captured before direct query so a failing but still-ready backend is visible. The probe makes no changes to EndpointSlices, CoreDNS, Redis, or extraction.

The probes log each failure or slow lookup with node, target, elapsed time, endpoint readiness, and direct-query results. Resolver errors appear only on failures. Successful checks are summarized periodically. CoreDNS metrics and probe logs together can distinguish a backend failure, EndpointSlice lag, and a node-local DNS service-path problem. They cannot by themselves prove the underlying host failure cause; NodeDiagnostic remains the host evidence path.

## Rollout

1. Validate Terraform input and rendered chart locally. Fault-test the probe locally with a ready but nonresponsive DNS server and a responsive server.
2. Review a production Terraform plan showing only the CloudWatch add-on configuration change. Confirm the existing agent still has its default config and the new collector is one deployment.
3. With explicit production approval, apply the Terraform change, wait for the new collector, confirm CoreDNS samples reach CloudWatch, then install the probe using the live Redis hostname. Check it lands only on extraction CPU nodes and logs successful lookups.
4. Observe a real incident. Do not inject DNS failures in production. A live fault exercise needs a separately authorized disposable EKS cluster with the same add-on version and node topology.

## Rollback

Disable `dns_observability.enabled` and apply a reviewed Terraform plan to remove the dedicated collector, without changing the existing CloudWatch agent. Uninstall only the `dns-probe` Helm release to stop synthetic queries and logs. Historical CloudWatch records remain subject to existing retention.
