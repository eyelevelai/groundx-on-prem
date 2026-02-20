# GroundX Metrics Monitoring

This folder contains the Kubernetes resources required to expose, scrape, and visualize GroundX metrics using Prometheus (`kube-prometheus-stack`) and Grafana.

At a high level, with this setup:

1. GroundX exposes a `/metrics` endpoint
2. Prometheus discovers and scrapes that endpoint
3. Grafana visualizes the collected metrics

## Table of Contents

- [Requirements](#requirements)
- [Files Overview](#files-overview)
  - [values.prometheus.yaml](#valuesprometheusyaml)
  - [service-monitor.yaml](#servicemonitoryaml)
  - [groundx-dashboard.json](#groundx-dashboardjson)
- [How It Fits Together](#how-it-fits-together)
- [Quick Verification](#quick-verification)

## Requirements

This setup assumes:
- `kube-prometheus-stack` is installed in the `monitoring` namespace
- GroundX `values.yaml` has `metrics.enabled: true` (default is `false`)

Note on autoscaling:

- `cluster.hpa: true` enables HPA autoscaling based on GroundX metrics.
- HPA is not required for monitoring, but must be enabled if you want autoscaling driven by these metrics.

Example setup:

```bash
# Create monitoring namespace
kubectl create namespace monitoring

# Add Prometheus Helm repo and refresh chart index
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install or upgrade kube-prometheus-stack with custom values
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f monitoring/values.prometheus.yaml

# Apply ServiceMonitor so Prometheus will scrape GroundX metrics
kubectl -n monitoring apply -f monitoring/service-monitor.yaml
```

Once installed:
- Prometheus runs in `monitoring`
- Grafana is deployed automatically
- `kube-state-metrics` exports Kubernetes metadata
- ServiceMonitors define scrape targets

---

## Files Overview

### values.prometheus.yaml

Helm values overrides for `kube-prometheus-stack`.

This file configures `kube-state-metrics` to export specific Kubernetes labels into Prometheus metrics.

By default, `kube-state-metrics` does **not** expose all object labels. If labels are not `allowlisted`, they will not appear in metrics such as `kube_node_labels`.

It also specifies that Prometheus and Grafana use the `eyelevel-cpu-only` node only.

#### What It Configures

```yaml
kube-state-metrics:
  nodeSelector:
    eyelevel_node: eyelevel-cpu-only

  metricLabelsAllowlist:
    - nodes=[
        eyelevel_node,
      ]
    - pods=[
        app,
      ]
```

This exposes the following labels to Prometheus and Grafana:

- `eyelevel_node` on Kubernetes **nodes** via `kube_node_labels`
- `app` on Kubernetes **pods** via `kube_pod_labels`

You will be able to use these labels to group and filter in PromQL and Grafana dashboards.

The node selector `eyelevel-cpu-only` restricts the Prometheus and Grafana pods to the `eyelevel-cpu-only` nodes.

---

### service-monitor.yaml

Defines a `ServiceMonitor` used by the Prometheus Operator.

This resource tells Prometheus:

- which namespace to look in
- which Service labels to match
- which port and path to scrape
- whether to use HTTP or HTTPS

Without this file, Prometheus will not discover or scrape the GroundX metrics service.

#### Deployment Assumptions

You may need to adjust:

- `metadata.namespace` and `metadata.labels.release`  
  Assumes Prometheus is installed in the `monitoring` namespace.

- `spec.namespaceSelector.matchNames`  
  Assumes GroundX is installed in the `eyelevel` namespace.

- `selector.matchLabels.app`  
  Assumes the metrics Service label is `app: metrics`.

If your deployment differs, update these fields accordingly.

Grafana then queries Prometheus to render dashboards.

---

### groundx-dashboard.json

Prebuilt Grafana dashboard for GroundX.

This dashboard includes panels for:

- API latency
- Queue backlog
- Celery task backlog
- Inference throughput
- Pod throughput pressure
- Pod replica counts
- System throughput
- Node counts (grouped by `eyelevel_node`)
- CPU and memory usage
- Per-pod resource breakdown
- Network throughput
- Disk IOPS and throughput

#### Importing the Dashboard

1. Open Grafana
2. Navigate to Dashboards → Import
3. Upload `groundx-dashboard.json`
4. Select your Prometheus datasource
5. Save

The dashboard assumes:

- `groundx_external_metric` exists
- Required labels are `allowlisted` via `values.prometheus.yaml`
- Default `kube-prometheus-stack` metrics are available

If panels show no data:

- Verify the Prometheus target is UP
- Confirm labels appear in `kube_node_labels` and `kube_pod_labels`
- Ensure namespace variables match your deployment

---

## How It Fits Together

```
GroundX Metrics Pod
        ↓
   Kubernetes Service
        ↓
   ServiceMonitor
        ↓
   Prometheus
        ↓
   Grafana
```

Prometheus scrapes the `/metrics` endpoint exposed by the GroundX service.  
Grafana then queries Prometheus to render dashboards.

---

## Quick Verification

Confirm the metrics endpoint is reachable (assumes the default `metrics` service name):

```bash
kubectl port-forward svc/metrics 8443:8443 -n eyelevel
curl -k https://localhost:8443/metrics
```

Confirm Prometheus is scraping the target:

```bash
kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090 -n monitoring
```

Open:

```
http://localhost:9090/targets
```

Your GroundX metrics target should appear as **UP**.

---

This folder provides the minimal configuration required to integrate GroundX into a standard Prometheus + Grafana stack.
