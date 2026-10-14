# Private file access deployment contract

`fileAccess.enabled` defaults to `false`. Existing storage, worker configuration,
workloads and ingress manifests remain unchanged while it is disabled. Enabling
it adds two FileAccess gateway replicas using the shared Go Deployment, Service,
health probes and config Secret. Gateway liveness uses `/health`; readiness
uses `/readyz` to check its database/schema and Redis dependencies. Streaming adds a network hop and gateway
bandwidth; replica and resource settings need measured workload limits.

This chart configuration is a candidate deployment surface. Render checks do not
certify storage compatibility, transport encryption, image compatibility or live
file authorization. Do not advertise or activate protection until the selected
backend's release gates pass.

## Endpoints and secrets

- `publicUrl` is the stable HTTPS file host root, without a bucket path. Configure
  its DNS and ingress to reach the gateway. Existing stored artifact URLs retain
  their paths; the ingress forwards paths, query strings (including `view=links`)
  and GroundX authentication headers without rewriting them.
- `trustedOrigins` optionally declares HTTPS origins for saved references from
  older file aliases (at most 32 origins, 2048 characters each). Entries have no credentials, query, fragment or nonroot
  path and must refer to the same configured storage namespace. The gateway
  resolves them through its configured bucket; this does not expose a store or
  grant reads across buckets. Inventory and verify aliases before declaring them.
- `storageEndpoint` is the full private HTTPS S3 API origin, including its port
  when required, without any path or trailing slash. Go clients, layout workers and their
  storage dependency checks use it independently of public URL SSL settings.
- `signingEndpoint` is the full reachable HTTPS native S3 API origin, without any path or trailing slash. Provision its native store route separately. Preserve the signed
  Host, path and query exactly and remove GroundX authentication headers before
  forwarding requests to storage. GroundX API keys and a storage web UI login do
  not authenticate this route. S4's native API is on port 7480; its UI is on 5000.
- For MinIO, AIStor and S4, `storageCredentialsSecretName` is required and
  references an existing Secret in the GroundX namespace with `GROUNDX_ACCESS_KEY_ID` and `GROUNDX_SECRET_ACCESS_KEY` (and
  `GROUNDX_SESSION_TOKEN` for a temporary session where supported). The same Secret
  reaches Go, Python and schema-migration consumers through `envFrom`. Enabled
  generated upload configuration omits inline credentials so these values win.
  Use store credentials, never shared account API keys. Native AWS S3 may omit
  this Secret and use the standard AWS credential chain, including IRSA.
- `serviceAccount.name` selects the gateway ServiceAccount. Set
  `fileAccess.serviceAccount.create=true` to create it and supply
  `fileAccess.serviceAccount.annotations`, including `eks.amazonaws.com/role-arn`
  for IRSA. The default is an existing/operator-owned account. Its namespace is
  the chart namespace; the role trust subject must match that namespace and name.
  A chart-created account's annotation changes restart the gateway through a pod
  hash. Provision role permissions and verify native AWS access independently.
- `caSecretName` optionally references a Secret containing `ca.crt`. The chart
  mounts it read-only at `/var/run/groundx/file-access/ca.crt` and sets
  `SSL_CERT_FILE` for application and migration consumers. Use a complete trust
  bundle when those processes also contact other HTTPS services. An empty value
  uses system trust. Provision certificates outside the chart and restart affected
  consumers after rotating credentials or trust Secrets; env imports and existing
  TLS client pools do not reload through the config hash.
- `tlsSecretName` is required for a chart-managed gateway ingress. Set
  `fileAccess.ingress.enabled` and the controller's `ingressClassName`. Disable
  the former `file.ingress` to prevent a second route to the same file host.
  `fileAccess.ingress.hostName` optionally selects a separately verified origin DNS
  name, defaulting to the public URL host. The ingress route and TLS hosts both
  use this name; provision a certificate covering it. This supports an HTTPS CDN
  origin without forwarding the viewer Host header. Public URL generation and
  gateway path resolution continue to use `publicUrl`; the chart does not verify
  DNS, certificate contents or origin encryption.

Clients must use HTTPS before adding authentication headers. Legacy HTTP file URLs
must be upgraded to HTTPS by the caller before authentication, never through an
authenticated HTTP redirect.

The chart rejects HTTP endpoints, delivery-host storage/signing loops, missing
credentials/TLS references, and ingress annotations that rewrite paths, introduce
caches/auth interception or inject proxy snippets. DNS aliases can still loop;
verify the actual routing topology. The generated ingress enforces NGINX HTTPS redirects, disables buffering and has
no cache configuration. Configure every ingress, proxy and CDN
on the delivery path to bypass response caching and honor `Cache-Control:
no-store`. Controller-global caching cannot be proven by a Helm render.

Layout configuration adds `uploadStorageEndpoint` and `uploadPublicRead=False`.
Extraction SDK settings add `storage_endpoint` and `public_read=False`.
The existing `uploadBaseURL`, `uploadReplaceURL`, bucket and region remain
presentation settings. Enabled public presentation URLs use the HTTPS scheme
from `publicUrl` and preserve the existing host, path and bucket exactly once.
Configured file and extraction presentation hosts must match the gateway host. Do not substitute the private origin into returned
artifact URLs or append a second bucket to a configured presentation root.

## Activation and rollback gates

`frontProxyTLSVerified` defaults to `false`. The chart exposes the gateway's
plain HTTP service behind operator-provisioned HTTPS termination; enablement
requires this assertion after verifying the complete HTTPS route and an encrypted
trusted or service-mesh backplane from that terminator to the gateway. An ingress
TLS Secret reference alone does not verify the backplane. Kubernetes networking
alone is not encrypted. The assertion is passed to the gateway, whose startup
refuses plaintext file service without it. Configure and verify the encrypted
backplane outside this chart before setting it to `true`.

`originsPrivate=true` is an operator assertion, not an automatic policy change or
an observed readiness test. Set it only after anonymous GET and HEAD are denied
on every native store alias, credentialed processing succeeds, network transport
is encrypted, and at-rest encryption is independently verified. Kubernetes
networking does not provide encryption. No startup action may rewrite an
existing bucket policy or make uploads public. Inventory and remove existing
anonymous grants under the deployment's approved change process.

Ship compatible API, gateway and worker images together. Pin the selected store's
exact release, image digest, chart/operator versions, topology and gateway image
digest in the release evidence. The schema-migration hook uses the configured
GroundX API image and needs its matching private-storage contract. Verify the
fresh-install and upgrade paths against that image before deployment.

Run public legacy, authenticated, wrong-owner, sharing, expiry, native PUT,
Range/HEAD/conditional, TLS/encryption and large X-Ray `view=links` cases against
every backend being advertised. Verify private worker ingest, extraction, copy
and callback transport, plus Arcadia legacy, Arcadia v1, generic v1 and ADP v1
without changing answer keys or returned bytes. Measure concurrent streams,
presentation memory, Redis headroom and cold mapping lookup load. S4's pinned
chart has one store replica; two gateway replicas do not make the store HA.

Retain private origins and policy records on rollback. Roll back only to a
compatible gateway version that enforces all active policies; return temporary
errors rather than restore anonymous access. Incomplete AIStor or S4 evidence
leaves those backends unadvertised and does not block independently verified
backends or the separate hosted release.
