## Why

An extraction worker failed to resolve the Redis hostname while one CoreDNS pod's node was unhealthy. Current logs do not show which DNS backend answered or timed out, so the cause cannot be established or distinguished from a transient node or service-path failure.

## What Changes

- Add an opt-in CoreDNS Prometheus scrape to the existing CloudWatch Observability EKS add-on. Run one dedicated collector deployment and retain the existing agent's defaults.
- Add an opt-in DNS probe sidecar to the existing extraction worker pods. It resolves the configured Redis hostname through the same pod resolver as the worker. On failure or a slow lookup it records current kube-dns EndpointSlice readiness and queries each CoreDNS pod directly.
- Document rollout, evidence review, and rollback. A local fault test proves the probe distinguishes a DNS backend timeout from a working backend even while both are advertised ready.

## Impact

- The default Terraform plan is unchanged. With the setting enabled, the CloudWatch add-on updates and one collector pod is added. The existing CloudWatch agent and GroundX workloads retain their current configuration.
- The probe adds a 10m CPU and 32Mi memory request to each extraction worker pod and requires a rolling worker restart. It reads only kube-dns EndpointSlices, sends DNS queries, and emits logs. It changes no application data or DNS routing.
- CloudWatch receives per-CoreDNS-pod request, response, and upstream health metrics and incurs additional log and custom-metric charges. Its agent drops CoreDNS request-duration histograms, so lookup duration comes from the probe logs. Missing recent samples can indicate a scrape or publication failure.
- The CloudWatch add-on and worker sidecars are active in production. No cluster fault was injected into production. A live fault exercise requires an authorized disposable matching cluster.

## Capabilities

### New Capabilities

- `eks-dns-incident-evidence`: opt-in per-pod CoreDNS telemetry and extraction-node DNS path diagnostics.

### Modified Capabilities

None.

## Open Questions

None for implementation. A comparable disposable EKS cluster is needed before a live fault-injection exercise.
