# EKS DNS evidence for extraction

The production EKS Terraform stack can add one CloudWatch collector for each CoreDNS pod's request volume, response codes, and upstream health failures. The main `cloudwatch-agent` keeps the explicit [EKS cost controls](eks-cost-controls.md), with Application Signals off and enhanced Container Insights on. The collector drops CoreDNS duration histograms, so an optional sidecar in `extract-agent` measures Redis lookup time from the same pod network and resolver as extraction. Failed or slow lookups record kube-dns EndpointSlice readiness and directly query each listed CoreDNS pod. Neither component repairs DNS or retries extraction.

## Preflight

Confirm the production AWS account `903713046261`, region `us-west-2`, cluster `eyelevel_890ng3`, and Kubernetes context `gx-prod-extract`. The Terraform state belongs to the existing `terraform/aws/eks` checkout. Do not initialize a new production state or use `bin/environment` for this update.

Run the local checks:

```sh
terraform -chdir=terraform/aws/eks validate
terraform -chdir=terraform/aws/eks test -filter=tests/node_diagnostics.tftest.hcl
python3 -m unittest discover -s src/groundx/tests -p 'test_dns_probe.py'
helm lint src/groundx --set extract.enabled=true --set extract.agent.enabled=true --set extract.agent.dnsProbe.enabled=true
```

With `dns_observability.enabled = true`, review a production Terraform plan against the current state. It must contain only an in-place `amazon-cloudwatch-observability` configuration update at the already installed add-on version. Stop on node-group, CoreDNS, stateful-resource, or version changes. Verify that `cloudwatch-agent` retains the explicit cost configuration and that `coredns-metrics` is one deployment. Applying the add-on update can roll CloudWatch monitoring components, but does not roll GroundX or CoreDNS workloads.

The `extract-agent` Deployment runs on `t3a.medium` CPU nodes with a limit of 17 pods per node. Several nodes were at that limit, so a separate probe DaemonSet could not cover the worker that encountered the failure. The sidecar uses the extraction pod's slot. It adds a 10m CPU and 32Mi memory request to each extraction pod and uses the cache hostname produced by the same chart. It makes one normal lookup per pod every 10 seconds by default and logs each failure or lookup slower than two seconds. Fluent Bit sends these logs to `/aws/containerinsights/eyelevel_890ng3/application`.

## Rollout

Review a server dry run of the current GroundX Helm release using its saved values plus:

```yaml
extract:
  agent:
    dnsProbe:
      enabled: true
    rolloutStrategy:
      maxSurge: 1
      maxUnavailable: 0
```

Also add required pod anti-affinity for `app: extract-agent` on `kubernetes.io/hostname` to keep the two workers on different nodes. Copy the live `extract-agent` node affinity into the same `extract.agent.affinity` value first: setting affinity replaces the chart's default node selection. The strategy keeps two ready workers during a normal rollout but can require a temporary additional CPU node. Confirm capacity or autoscaling headroom before applying. Check active Celery tasks. Stop if the Helm upgrade proposes unrelated application changes. The rendered change should add only the probe ConfigMap, kube-system EndpointSlice read Role and RoleBinding, and the sidecar, strategy, and placement settings on `extract-agent`.

Use `--reset-then-reuse-values` for the Helm upgrade so the new probe defaults, including its image and resource limits, are present along with the release's existing values. Verify the rendered probe image is nonempty. `--reuse-values` alone omits those new defaults. The currently deployed chart and the repository chart both report version `0.2.7` but render different unrelated services, so compare every resource against `helm get manifest` before applying a repository checkout. Production revision 399 was built from the stored release chart with this probe feature and placement setting, avoiding unrelated changes.

Upgrade the GroundX release with those values only after the rollout review, then wait for both `extract-agent` pods to become ready on different extraction CPU nodes. Confirm both have the `dns-probe` container and no restarts. The sidecar uses the pod's existing service account. Its added Kubernetes permission is limited to listing EndpointSlices in `kube-system`.

```sh
kubectl --context gx-prod-extract -n eyelevel get pods -l app=extract-agent -o wide
kubectl --context gx-prod-extract -n eyelevel logs -l app=extract-agent -c dns-probe --prefix=true --tail=30
aws logs describe-log-groups --region us-west-2 --log-group-name-prefix /aws/containerinsights/eyelevel_890ng3/prometheus
aws cloudwatch list-metrics --region us-west-2 --namespace ContainerInsights/Prometheus --metric-name coredns_dns_responses_total
```

Check that the original `/aws/containerinsights/eyelevel_890ng3/performance` and application groups continue receiving events. On a future resolver failure, compare the sidecar's endpoint readiness and direct results with per-pod CoreDNS metrics and NodeDiagnostic evidence from the affected node. These signals identify which DNS path failed; they do not alone establish why a host failed.

## Rollback

Disable `extract.agent.dnsProbe.enabled` while retaining the existing extraction placement and rollout strategy, then review and apply the Helm rollback. Disable `dns_observability.enabled` and apply a reviewed Terraform plan to remove the dedicated collector. Historical logs and metrics remain under existing retention. Do not inject a DNS failure in production. The saved `test-eks` context is an unavailable AKS endpoint, and this account currently has no reachable disposable EKS cluster for a live fault exercise.
