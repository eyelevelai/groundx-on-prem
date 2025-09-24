# Enabling Internal TLS

By default the GroundX chart does **not** enable TLS for internal (pod‑to‑pod, service‑to‑service, etc...) communications.

If you would like to enable internal TLS, set `tls.existingSecret` in `values.yaml` to the name of an existing Kubernetes TLS Secret (`type: kubernetes.io/tls`) in the target namespace.

## Creating a Self-Signed TLS Secret

A ready‑to‑use Terraform module is provided in [`scripts/cert/`](./). It generates a self‑signed CA and a leaf certificate for `*.<namespace>.svc`, then creates a TLS Secret in the namespace.

### Pre-Requisites

```markdown
- `openssl`
- `terraform` v1.0+
```

### Running the Terraform Script

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
tls:
  existingSecret: "eyelevel-cert"
```

### Uninstalling the Self-Signed TLS Secret

If, for some reason, you would like to uninstall the TLS secret while **not** destroying the namespace, run the following commands:

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
