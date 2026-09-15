# Large file delivery worker

The `largeFileDeliver` worker is disabled by default. Absent or false `enabled`
settings preserve the existing workload, topic and Go configuration output.
Enable it only with the compatible cashbot-go producer and delivery build from
`route-large-files-before-preprocess`. Installing the worker does not enable
account routing.

## Configuration

Set these fields under `largeFileDeliver`:

| Field | Required input |
| --- | --- |
| `enabled` | `true` to render the worker and shared routing configuration. |
| `image` | Explicit image containing the `server/LargeFileDeliver` binary, built with `Dockerfile.large-file-delivery`. |
| `concurrency` | Positive maximum simultaneous deliveries per worker. |
| `maxUploadDuration` | Positive duration, expressed in whole milliseconds, seconds, minutes or hours. |
| `counting.maxCountDuration` | Positive counting duration. |
| `counting.helperPath` | Path in the producer image to the bounded PDF helper, normally `/app/large-file-pdf-count`. |
| `counting.tempDir` | Optional producer temporary directory with sufficient writable capacity. |
| `resources.requests` and `resources.limits` | Explicit CPU and memory settings for the delivery container. |
| `credentials` | Map from trusted credential reference to `secretName` and `secretKey`. At least one binding is required. |
| `replicas.desired` | Optional worker count, default one. No new autoscaler is introduced. |

The worker also accepts the standard Go workload scheduling, labels, annotations,
security context, service account, port and image pull policy settings. Its default
service name is `large-file-delivery`, with health probes on port 8080.

Set producer image and resources through the existing `queue` settings. The
producer image must contain both `QueueTrainFile` and the PDF helper. Neither
an existing chart version nor a successful render proves that an image contains
the new binaries. File bytes use the account's existing `maxFileSize`, saved
for counting and delivery retries. Zero remains unlimited. There is no chart
byte limit or separate diverted-page ceiling. Size counting time, producer concurrency, temporary
disk and memory together; choose delivery time, concurrency and memory together.
Real-environment capacity and Drive checks gate account activation.

Remove `largeFileDeliver.counting.maxPDFBytes` from existing values when upgrading
and deploy a producer build that reads the account limit. Old producer builds
require that removed setting and must not be used with this chart configuration.
Existing saved runs retain their original byte limits and receipts.

## Shared Google credentials

OCR and large-file delivery can share one service-account credential. Supply the
chart-relative JSON file once, using the same packaged-file pattern as OCR:

```yaml
google:
  credentials: files/google/service-account.json

layout:
  ocr:
    enabled: true
    type: google
    project: example-project

largeFileDeliver:
  credentials:
    operations-drive:
      sharedGoogle: true
```

The delivery worker still needs the other enabled-worker settings above. Its
account policy selects `credentialRef: operations-drive`. Google OCR inherits
the shared source only when enabled with `type: google` and no
`layout.ocr.credentials` override. Delivery must explicitly select
`sharedGoogle: true`; existing per-reference Secret settings do not switch.

Alternatively, supply a pre-existing Secret without packaging any credential:

```yaml
google:
  existingSecret: company-google-credentials
  secretKey: credentials.json
```

`secretKey` defaults to `credentials.json`. Do not specify both
`google.credentials` and `google.existingSecret`. When replacing layered values,
set the unused source to `null`. A delivery entry accepts either
`sharedGoogle: true` or the existing `secretName`/`secretKey` pair, never both.

The managed file becomes one `google-credentials` Secret, created only while
at least one consumer uses it. Disabling OCR does not remove it while delivery
still uses it. An existing Secret is neither created nor deleted by this chart.
Layout consumers retain `/app/credentials.json`; delivery retains its registered
credential-file path. Credential bytes never enter the common Go config or
unrelated Go, extraction, or workspace pods.

Changing the packaged file changes credential hashes and rolls its consuming
layout and delivery pods. With an existing Secret, update the Secret and restart
consuming layout pods: their existing `subPath` mount does not receive live Secret
updates. Delivery mounts a directory; new delivery clients read updated files
after Kubernetes propagates the Secret. Keep the old Google key active until
consumers have picked up the replacement and pending work is reconciled.

Keep real files, rendered Secrets, and private chart packages outside version
control and public registries. Helm release storage also contains managed Secret
contents. A shared service account grants both consumers its Google permissions;
retain separate per-service credentials where that access must be isolated.
Before removing the shared source during rollback, restore each active consumer's
per-service credential configuration. Do not remove delivery access while work is
pending. Existing legacy-only values retain their rendered behavior.

## Credentials and transport

Provision the service-account JSON in an existing Kubernetes Secret. Set each
credential reference's `secretName` and `secretKey` to that Secret and data key.
The chart mounts only that key, read-only, in the delivery worker at
`/var/run/groundx/large-file/<reference>/credentials.json`. The shared Go
configuration contains this path, not the JSON. The producer validates the
registered reference without reading credentials or mounting the Secret.
Secret rotation follows Kubernetes volume updates; newly constructed credential
clients read the updated file. Do not commit credentials in values or examples.

The destination must be an authorized Google Workspace Shared drive folder
writable by the configured service account. Customer account metadata selects
only an approved folder and registered credential reference. Network access to
Google's OAuth and Drive endpoints is required for this optional service.

`stream.topics.largeFile` uses the existing stream override conventions.
Kafka defaults to `large-file`; `broker`, `topic` and `groupId` can be
overridden. The chart's existing topic mechanism uses the worker replica count
as the partition count when managing Kafka topics. Externally managed Kafka
topics must be provisioned by their operator.

For an externally managed SQS queue, set `type: sqs`, `url` and the deployment's
AWS region. The chart creates no delivery Kafka topic in this mode. Prefer the
existing workload-identity or environment-secret configuration for AWS access.
Queue visibility, retention and dead-letter handling must allow the measured
upload and recovery envelope. This chart does not provision SQS resources.

Both producer and consumer receive `queues.largeFile`. The chart also
renders `largeFileRouting`, `largeFileDelivery`, and
`largeFileDeliveryServer`. Enabling or changing these shared settings changes
Go workload configuration hashes and can restart existing producer pods.

## Rollout and recovery

Install the additive database column before the updated monitor and workers.
Keep account policies disabled until all old producer workers are replaced,
transport and credentials are ready, and the cashbot-go activation record has
passing capacity and authorized Drive-delivery evidence. Local tests use small
synthetic limits and fake destinations; they do not qualify live capacity.

Disable account policy first during rollback. Retain the worker, queue/topic,
credential bindings and database routing receipts until pending publication,
delivery and callback finalization are drained or reconciled. Removing the
worker or its dependencies first can strand accepted documents. GroundX
rollback or document deletion does not delete the delivered Drive copy.

## Local verification

Run from the repository root. No command below deploys or uploads files.

```sh
.build/bin/validate-helm.sh
helm lint src/groundx
helm template local src/groundx -f src/groundx/values/minikube/values.yaml
helm template local src/groundx -f src/groundx/tests/files/values.large-file.yaml
```

The enabled fixture uses test-only image, limits and Secret names. The existing
`golang_test.yaml`, `resources_test.yaml`, and `stream_test.yaml` suites each
snapshot enabled Kafka and SQS renders using this fixture. Their original
disabled snapshots remain unchanged. Field assertions in those same suites
check credential isolation and transport settings.

Validate the actual Go configuration from the cashbot-go worktree with:

```sh
LARGE_FILE_CHART_PATH=/absolute/path/to/groundx-on-prem/src/groundx \
  go test -tags groundx_chart_integration ./pkg/config \
  -run '^TestLargeFileChartConfiguration$' -count=1
```

That test renders Kafka and SQS configurations, decodes them into cashbot-go's
runtime types, verifies disabled behavior, and checks schema rejection of
invalid delivery inputs. It requires Helm and the matching dependent chart.
