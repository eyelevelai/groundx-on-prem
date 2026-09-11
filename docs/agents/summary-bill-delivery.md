# Summary bill delivery worker

The `summaryBillDeliver` worker is disabled by default. Absent or false `enabled`
settings preserve the existing workload, topic and Go configuration output.
Enable it only with the compatible cashbot-go producer and delivery build from
`route-summary-bills-before-preprocess`. Installing the worker does not enable
account routing.

## Configuration

Set these fields under `summaryBillDeliver`:

| Field | Required input |
| --- | --- |
| `enabled` | `true` to render the worker and shared routing configuration. |
| `image` | Explicit image containing the `server/SummaryBillDeliver` binary, built with `Dockerfile.summary-bill-delivery`. |
| `concurrency` | Positive maximum simultaneous deliveries per worker. |
| `maxUploadDuration` | Positive duration, expressed in whole milliseconds, seconds, minutes or hours. |
| `counting.maxPDFBytes` | Positive byte limit for counting. There is no separate diverted-page ceiling. |
| `counting.maxCountDuration` | Positive counting duration. |
| `counting.helperPath` | Path in the producer image to the bounded PDF helper, normally `/app/summary-bill-pdf-count`. |
| `counting.tempDir` | Optional producer temporary directory with sufficient writable capacity. |
| `resources.requests` and `resources.limits` | Explicit CPU and memory settings for the delivery container. |
| `credentials` | Map from trusted credential reference to `secretName` and `secretKey`. At least one binding is required. |
| `replicas.desired` | Optional worker count, default one. No new autoscaler is introduced. |

The worker also accepts the standard Go workload scheduling, labels, annotations,
security context, service account, port and image pull policy settings. Its default
service name is `summary-bill-delivery`, with health probes on port 8080.

Set producer image and resources through the existing `queue` settings. The
producer image must contain both `QueueTrainFile` and the PDF helper. Neither
an existing chart version nor a successful render proves that an image contains
the new binaries. Choose counting bytes/time, producer concurrency, temporary
disk and memory together; choose delivery time, concurrency and memory together.
Real-environment capacity and Drive checks gate account activation.

## Credentials and transport

Provision the service-account JSON in an existing Kubernetes Secret. Set each
credential reference's `secretName` and `secretKey` to that Secret and data key.
The chart mounts only that key, read-only, in the delivery worker at
`/var/run/groundx/summary-bill/<reference>/credentials.json`. The shared Go
configuration contains this path, not the JSON. The producer validates the
registered reference without reading credentials or mounting the Secret.
Secret rotation follows Kubernetes volume updates; newly constructed credential
clients read the updated file. Do not commit credentials in values or examples.

The destination must be an authorized Google Workspace Shared drive folder
writable by the configured service account. Customer account metadata selects
only an approved folder and registered credential reference. Network access to
Google's OAuth and Drive endpoints is required for this optional service.

`stream.topics.summaryBill` uses the existing stream override conventions.
Kafka defaults to `file-summary-bill`; `broker`, `topic` and `groupId` can be
overridden. The chart's existing topic mechanism uses the worker replica count
as the partition count when managing Kafka topics. Externally managed Kafka
topics must be provisioned by their operator.

For an externally managed SQS queue, set `type: sqs`, `url` and the deployment's
AWS region. The chart creates no delivery Kafka topic in this mode. Prefer the
existing workload-identity or environment-secret configuration for AWS access.
Queue visibility, retention and dead-letter handling must allow the measured
upload and recovery envelope. This chart does not provision SQS resources.

Both producer and consumer receive `queues.fileSummaryBill`. The chart also
renders `summaryBillRouting`, `summaryBillDelivery`, and
`summaryBillDeliveryServer`. Enabling or changing these shared settings changes
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
helm template local src/groundx -f src/groundx/tests/files/values.summary-bill.yaml
```

The enabled fixture uses test-only image, limits and Secret names. Validate the
actual Go configuration from the cashbot-go worktree with:

```sh
SUMMARY_BILL_CHART_PATH=/absolute/path/to/groundx-on-prem/src/groundx \
  go test -tags groundx_chart_integration ./pkg/config \
  -run '^TestSummaryBillChartConfiguration$' -count=1
```

That test renders Kafka and SQS configurations, decodes them into cashbot-go's
runtime types, verifies disabled behavior, and checks schema rejection of
invalid delivery inputs. It requires Helm and the matching dependent chart.
