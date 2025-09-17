# GroundX RAG on Prem: Secure, Accurate, Scaled

**Pre-Requisites**

```markdown
- `kubectl` (or `oc`) configured to a namespace you can write to (e.g., `eyelevel`)
- `helm` v3.8+
```

1. Install

```bash
helm upgrade --install groundx oci://public.ecr.aws/c9r4x6y5/helm/groundx -n eyelevel -f values.yaml
```

## Enabling Internal TLS

By default this chart does **not** enable TLS for internal (pod‑to‑pod, service‑to‑service, etc...) communications.

If you would like to enable internal TLS, set `tls.existingSecret` in `values.yaml` to the name of an existing Kubernetes TLS Secret (`type: kubernetes.io/tls`) in the target namespace.

### Creating a Self-Signed TLS Secret

A ready‑to‑use Terraform module is provided in [`scripts/cert/`](./scripts/cert/). It generates a self‑signed CA and a leaf certificate for `*.<namespace>.svc`, then creates a TLS Secret in the namespace.

**Pre-Requisites**

```markdown
- `openssl`
- `terraform` v1.0+
```

To run the Terraform module with default values:

```bash
terraform -chdir=scripts/cert init --upgrade
terraform -chdir=scripts/cert apply -auto-approve
```

With the defaults in `variables.tf`, this will:

- Create a namespace `eyelevel` if it does not already exist
- Create a TLS Secret `eyelevel-cert` (type `kubernetes.io/tls`)
- Install the TLS secret in namespace `eyelevel`

You can then configure `values.yaml` to use this TLS secret:

```yaml
createNamespace: false
tls:
  existingSecret: "eyelevel-cert"
```

Note: it is important that you set `createNamespace` to `false` in `values.yaml` if you choose to use this Terraform module.

**Uninstalling**

To uninstall the TLS secret while **not** destroying the namespace, run the following commands:

```bash
terraform -chdir=scripts/cert init --upgrade
terraform -chdir=scripts/cert destroy -auto-approve \
  -target=tls_private_key.ca_key \
  -target=tls_self_signed_cert.ca_cert \
  -target=tls_private_key.service_key \
  -target=tls_cert_request.service_csr \
  -target=tls_locally_signed_cert.service_cert \
  -target=kubernetes_secret.ssl_cert
```

## Installing the NVIDIA GPU Operator

```bash
terraform -chdir=terraform/nvidia-operator init --upgrade
terraform -chdir=terraform/nvidia-operator apply -auto-approve
```

```bash
terraform -chdir=terraform/nvidia-operator init --upgrade
terraform -chdir=terraform/nvidia-operator destroy -auto-approve
```

## Deploying with Helm

```bash
kubectl create namespace eyelevel
```

## Creating a Default PV Class

```bash
helm install prereqs groundx/prereqs -n eyelevel
```

## Installing services

### MySQL

```bash
helm repo add percona https://percona.github.io/percona-helm-charts/
helm repo update

helm install db-operator percona/pxc-operator -n eyelevel -f src/groundx/services/values.db.operator.yaml --version 1.15.1
helm install db-cluster percona/pxc-db -n eyelevel -f src/groundx/services/values.db.cluster.yaml --version 1.15.1
```

### MinIO

```bash
helm repo add minio-operator https://operator.min.io/
helm repo update

helm install file-operator minio-operator/operator -n eyelevel -f src/groundx/services/values.file.operator.yaml --version 6.0.3
helm install file-cluster minio-operator/tenant -n eyelevel -f src/groundx/services/values.file.tenant.yaml --version 6.0.3
```

### OpenSearch

```bash
helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm repo update

helm install opensearch opensearch/opensearch -n eyelevel -f src/groundx/services/values.search.yaml --version 2.23.1
```

### Kafka

```bash
helm install stream-operator oci://quay.io/strimzi-helm/strimzi-kafka-operator -n eyelevel -f src/groundx/services/values.stream.yaml --version 0.47.0
```

## GroundX

```bash
helm repo add groundx https://registry.groundx.ai/helm
helm repo update

helm install groundx groundx/groundx -n eyelevel
```
