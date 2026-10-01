# EKS DNS evidence for extraction

The production EKS Terraform stack can add one CloudWatch collector for each CoreDNS pod's request volume, response codes, request duration, upstream health failures, and scrape availability. The default `cloudwatch-agent` entry remains unmodified. The separate `dns-probe` chart checks Redis name resolution from every extraction CPU node. On failure or a lookup slower than two seconds, it records kube-dns EndpointSlice readiness and sends a direct query to every listed CoreDNS pod. It does not repair DNS or restart extraction.

## Preparation

Use the production AWS account `903713046261`, region `us-west-2`, cluster `eyelevel_890ng3`, and Kubernetes context `gx-prod-extract`. Confirm that identity and context before any apply. The Terraform stack keeps its state in `terraform/aws/eks`; use the state-owning checkout and its ignored `terraform/aws/env.tfvars`. Never initialize a new state or run `bin/environment` for this change.

The matching `test-eks` kube context points to an unavailable AKS endpoint. The other listed EKS clusters in this account no longer exist. The local fault test is useful for probe logic, but does not replace a live canary. Do not inject DNS failure into production.

Run the local checks:

```sh
terraform -chdir=terraform/aws/eks validate
terraform -chdir=terraform/aws/eks test -filter=tests/node_diagnostics.tftest.hcl
python3 -m unittest discover -s monitoring/dns-probe/tests
helm lint monitoring/dns-probe --set-string targetHost=redis.example.internal
```

Before rollout, review a production Terraform plan with `dns_observability.enabled = true`. Confirm that the only intended infrastructure change is `amazon-cloudwatch-observability` configuration, with the installed add-on version unchanged. Do not apply if Terraform proposes node groups, CoreDNS, stateful resources, or an add-on version change. Confirm the new `agents` array contains `{name: cloudwatch-agent}` without overrides and one `coredns-metrics` deployment. The add-on update rolls CloudWatch monitoring components; existing application workloads do not roll.

Get the current Redis hostname from the live GroundX Helm values, rather than copying an old endpoint:

```sh
helm --kube-context gx-prod-extract -n eyelevel get values groundx -o json | jq -r '.cache.existing.addr'
```

After the reviewed Terraform apply and explicit production approval, install the probe with that hostname:

```sh
helm upgrade --install dns-probe monitoring/dns-probe \
  --kube-context gx-prod-extract -n kube-system \
  --set-string targetHost="$(helm --kube-context gx-prod-extract -n eyelevel get values groundx -o json | jq -r '.cache.existing.addr')"
```

Verify the DaemonSet pods are on the same CPU-only node pool as `extract-agent`, and no GPU nodes. The probe uses the normal `ClusterFirst` pod resolver. Each node logs one success summary per minute by default, and every failure or slow lookup immediately. The existing Fluent Bit application log pipeline forwards these logs to `/aws/containerinsights/eyelevel_890ng3/application`.

```sh
kubectl --context gx-prod-extract -n kube-system get pods -l app=dns-probe -o wide
kubectl --context gx-prod-extract -n kube-system logs -l app=dns-probe --prefix=true --tail=30
aws logs describe-log-groups --region us-west-2 --log-group-name-prefix /aws/containerinsights/eyelevel_890ng3/prometheus
aws cloudwatch list-metrics --region us-west-2 --namespace ContainerInsights/Prometheus --metric-name coredns_dns_responses_total
```

Check that the existing `/aws/containerinsights/eyelevel_890ng3/performance` and application log groups continue receiving events. On a future resolver failure, compare probe failure records, each endpoint's ready state and direct-query result, per-pod CloudWatch CoreDNS metrics, and NodeDiagnostic evidence from the affected node. If the API is unreachable, the probe logs `endpoints_error`; that alone cannot prove which CoreDNS backend failed.

## Rollback

Uninstall only `dns-probe` from `kube-system`. Set `dns_observability.enabled = false`, review the resulting Terraform plan, and apply it to remove the dedicated collector. The original CloudWatch agent remains. Historical logs and metrics remain under existing retention settings.
