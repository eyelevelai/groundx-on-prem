# Private file access deployment contract

`fileAccess.enabled` defaults to `false`. Existing storage, worker configuration,
workloads and ingress manifests remain unchanged while it is disabled, except
that a set `caSecretName` still delivers its CA bundle (see below). Enabling
it adds two FileAccess gateway replicas using the shared Go Deployment, Service,
health probes and config Secret. Gateway liveness uses `/health`; readiness
uses `/readyz` to check its database/schema and Redis dependencies. Streaming adds a network hop and gateway
bandwidth; replica and resource settings need measured workload limits.

This chart configuration is a candidate deployment surface. Render checks do not
certify storage compatibility, transport encryption, image compatibility or live
file authorization. Do not advertise or activate protection until the selected
backend's release gates pass.

## Extraction storage setting: `public_read`

This is a generated Python service setting, not an account/bucket/document policy
or a `values.yaml` field. Its SDK default is `True`. In this chart, file access
is disabled by default and the SDK default remains in effect; a chart-created
file-access gateway causes extraction config to set `public_read=False`.

For a new MinIO/S4 bucket, `True` allows anonymous downloads and `False` leaves
it private. Existing buckets are not changed. The S3 adapter does not use this
flag to change bucket permissions. Operators must separately verify that direct
storage access cannot bypass the gateway. See the
[SDK storage-setting definition](https://github.com/eyelevelai/groundx-python/blob/main/CONTRIBUTING.md#extraction-storage-settings).

Extraction also uses `False` to enable image-path validation and private image
delivery. Its checks must accept the current document's original PNG/JPG source
as well as generated pages/crops. Do not enable anonymous storage reads or set
`True` to bypass a failed image check. Verify full public/protected PNG/JPG/PDF
extraction, not only chart rendering or downloads. Internal file reads must reuse
service credentials and existing document authorization regardless of customer policy.

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
  reaches Go storage clients, layout and extraction workloads, and the schema-migration
  hook through `envFrom`. Ranker, summary API/inference, workspace and metrics receive
  no implicit storage Secret; explicit operator `cluster.secrets` retain global scope. Enabled
  generated upload configuration omits inline credentials so these values win.
  Use store credentials, never shared account API keys. Native AWS S3 may omit
  this Secret and use the standard AWS credential chain, including IRSA.
  Remove nonempty `file.username`, `file.password` and `file.token` before enabling
  file access. Also remove `extract.file.username` and `extract.file.password` when
  extraction is enabled. Rendering rejects these inputs because enabled upload
  configuration would discard them, even when a storage Secret is configured.
- `serviceAccount.name` selects the gateway ServiceAccount. Set
  `fileAccess.serviceAccount.create=true` to create it and supply
  `fileAccess.serviceAccount.annotations`, including `eks.amazonaws.com/role-arn`
  for IRSA. The default is an existing/operator-owned account. Its namespace is
  the chart namespace; the role trust subject must match that namespace and name.
  A chart-created account's annotation changes restart the gateway through a pod
  hash. Provision role permissions and verify native AWS access independently.
- `caSecretName` optionally references a Secret containing `ca.crt`. The chart
  mounts it read-only at `/var/run/groundx/file-access/ca.crt` and sets
  `SSL_CERT_FILE` in every GroundX application workload, the metrics server and
  the migration Job included, whether or not file access is enabled. Create the
  Secret in the chart namespace before the install or upgrade that sets
  `caSecretName`; a missing Secret or `ca.crt` key stops those pods from
  starting. Use a complete trust bundle when those processes also contact other
  HTTPS services. An empty value uses system trust. Provision certificates outside the chart and restart affected
  consumers after rotating credentials or trust Secrets; env imports and existing
  TLS client pools do not reload through the config hash.
- `tlsSecretName` is required for a chart-managed gateway ingress. Set
  `fileAccess.ingress.enabled` and the controller's `ingressClassName`. Native
  `file.ingress` may remain on a separate signing/store hostname. Its effective
  templated hostname must differ from `publicUrl` and an enabled chart gateway
  hostname. The public host remains protected with external gateway ingress;
  a disabled unused chart ingress hostname may name the native store route.
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
When extraction and file access are enabled, the effective extraction bucket must
match `file.bucketName`. Omit `extract.file.bucketName` to inherit it, or set the
same value explicitly. The gateway and native-link signer use one storage bucket;
a separate private extraction bucket cannot be served through that gateway.
Rendering rejects the mismatch. Separate extraction buckets remain available with
file access disabled, and an unused extraction setting is ignored while extraction
is disabled. The guard does not migrate existing objects.

The existing `uploadBaseURL`, `uploadReplaceURL`, bucket and region remain
presentation settings. Enabled public presentation URLs use the HTTPS scheme
from `publicUrl` and preserve the existing host, path and bucket exactly once.
Configured file and extraction presentation hosts must match the gateway host. Do not substitute the private origin into returned
artifact URLs or append a second bucket to a configured presentation root.

## Upgrade existing files before activation

Use compatible Cashbot API, gateway and worker images. Stop older writers, run the
normal database upgrade, then deploy compatible writers before resuming ingestion.
The upgrade builds a historical-source index once. It reads old task metadata in
small batches and does not access object storage. Budget upgrade time for that work.
See the [backend upgrade guide](https://github.com/EyeLevel-ai/cashbot-go/blob/master/docs/agents/database-upgrades.md#historical-source-lookup)
for the schema, rollout and rollback requirements.

An older original without a binding migrates on its first read. The service looks
up its exact indexed reference, verifies the saved file and current document owner,
then saves the binding. It checks current references first, then historical ones.
Downloads do not scan the database or storage. No separate binding backfill command
is required. Deleted documents and detected conflicts remain unavailable; legacy
shared-source repair is a separate operator procedure.

Verify older original and X-Ray downloads before cutover, including protected owner
success and anonymous/wrong-owner denial. The API release must resolve saved HTTP
references under configured HTTPS roots. Callers must use HTTPS before sending a
key. Keep native storage private and retain indexes and bindings on rollback.
These database and ownership rules apply to S3, MinIO, AIStor and S4; each backend
still requires its own deployment acceptance tests.

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

## API and agent usage

The chart deploys the existing GroundX API and file gateway, not a separate policy
API. Compatible API images accept an initial `fileAccess` on bucket creation and
each ingested document. Omitted/null inherits. Later changes use the current policy
revision. The same ancestor restrictions and private staging rules apply on-prem;
a protected local file in a public bucket needs a private reservation before bytes.
Only effective-protected uploads reserve private staging. Public uploads retain
legacy staging even when the feature is enabled; PUT expiry does not expire their
uploaded sources or impose an ingest deadline.

Use the configured local GroundX API URL for policy/link/upload control requests and
the configured native signing endpoint for exact presigned PUT/GET requests. Never
use the hosted public upload broker for private on-prem data. Keep API credentials
out of native requests. Stable public links do not expire; protected stable reads
require current API authentication. Temporary bearer links expire and can be
forwarded until then.

The Studio Harness `groundx-api` file-access reference and standalone `groundx-mcp`
file-access workflow own agent instructions. MCP support needs a compatible local
API image and verified route/auth/issuer configuration. Hosted OAuth URLs are not
an air-gapped configuration. Discovery/schema success is not live transport proof.
SDK model/method availability must match the selected client version; use the
documented REST flow when the installed SDK lacks a method.

Capability changes must assess these operator instructions, Fern human docs, Harness
references, MCP and SDK examples together. Record image/client identities and the
selected storage vendor's acceptance result before advertising support.

## Unified upload signing

The existing GroundX API issues upload URLs for public and protected buckets,
including installations with `fileAccess.enabled=false`. It uses the configured
S3 or MinIO-compatible store. MinIO, AIStor and S4 use the existing compatible
storage implementation; vendor acceptance remains a release gate. File bytes go
directly to storage. No hosted upload broker, extra signing service, queue or
database provider is needed.

Set optional `file.signingEndpoint` to the native origin reachable by upload clients
when it differs from the existing file endpoint. Public local installations may
retain HTTP; use HTTPS for sensitive content. Existing inline credentials and the
ambient credential chain remain supported while protection is disabled. With
protection enabled, `fileAccess.signingEndpoint` and its existing HTTPS, private
origin, credential and schema gates remain authoritative. This setting does not
enable the gateway or enroll public uploads in file-access policies.

Use the local API base for SDK, widget and MCP upload issuance. New clients do not
fall back to the hosted FileUpload service. Existing anonymous `/upload/{type}`
request and response formats remain compatibility adapters to the same signing
implementation. Hosted routing and retirement of the standalone Lambda require a
separate deployment after all legacy routes are verified.

## Temporary file links

To enable temporary links with an explicit authentication choice, set
`fileAccess.linkSigningKeySecretName` to an existing Kubernetes Secret. It must
contain `GROUNDX_FILE_LINK_SIGNING_KEY`: at least 32 random bytes, base64-encoded.
The chart gives this key only to the API and FileAccess pods. Use the same key on
all replicas. Do not put its value in Helm values, browser code or storage settings.

On `file-link`, `requireAuthentication: true` requires current owner credentials;
false allows anyone with the link to read it. Both expire. Leaving out the field
keeps existing storage-signed sharing. Saved file URLs and policies do not change.
Without the Secret, older links work and the new option returns 404.

Deploy compatible file-service and API images before issuing new links. The key
is read at startup: restart both after changing the Secret and verify they use the
same value. Rotation cancels links signed with the old key. During rollback, keep
the verifier and key until those links expire. These settings do not establish
MinIO, AIStor or S4 certification; test each actual deployment separately.
