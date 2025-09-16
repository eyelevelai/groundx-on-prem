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
