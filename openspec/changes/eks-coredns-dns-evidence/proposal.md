## Why

An extraction worker failed to resolve the Redis hostname while one CoreDNS pod's node was unhealthy. Current logs do not show which DNS backend answered or timed out, so the cause cannot be established or distinguished from a transient node or service-path failure.

## What Changes

- Add an opt-in CoreDNS Prometheus scrape to the existing CloudWatch Observability EKS add-on. Run one dedicated collector deployment and retain the existing agent's defaults.
- Add a small, independently installed DNS probe on extraction CPU nodes. It resolves the configured Redis hostname through the pod's normal resolver. On failure or a slow lookup it records current kube-dns EndpointSlice readiness and queries each CoreDNS pod directly.
- Document rollout, evidence review, and rollback. A local fault test proves the probe distinguishes a DNS backend timeout from a working backend even while both are advertised ready.

## Impact

- The default Terraform plan is unchanged. With the setting enabled, the CloudWatch add-on updates and one collector pod is added. The existing CloudWatch agent and GroundX workloads retain their current configuration.
- The probe is a separate Helm release in `kube-system`, limited to extraction CPU nodes. It reads only kube-dns EndpointSlices, sends DNS queries, and emits logs. It changes no application data or DNS routing.
- CloudWatch receives per-CoreDNS-pod metrics and incurs additional log and custom-metric charges. The probe adds a small CPU and memory request per extraction node and low-rate DNS traffic.
- Production is the only currently reachable matching cluster. No cluster fault is injected into production. Applying either component requires a reviewed production plan and explicit approval.

## Capabilities

### New Capabilities

- `eks-dns-incident-evidence`: opt-in per-pod CoreDNS telemetry and extraction-node DNS path diagnostics.

### Modified Capabilities

None.

## Open Questions

None for implementation. A comparable disposable EKS cluster is needed before a live fault-injection exercise.
