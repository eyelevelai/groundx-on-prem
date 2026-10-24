# Optional post-processing

Post-processing is disabled by default. Enabling `postProcess.enabled` creates
a dedicated worker and emits `queues.filePostProcess` and `postProcessFileServer`
in the shared Go configuration. Without that queue, custom post-processing is
unsupported. It does not fall back to the ordinary file-processing queue.

Enable only with compatible GroundX API, file-processing and post-processing
images from `cashbot-go`. The worker image must contain the
`server/PostProcessTrainFile` binary built with `Dockerfile.post-process`.

```yaml
postProcess:
  enabled: true
  retryEnabled: false
  image: registry.example.com/groundx/post-process:compatible-version
  concurrency: 2
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 1
      memory: 256Mi
```

The queue defaults to Kafka topic and consumer group `file-post-process`, using
the existing stream broker. Override broker, topic and group through
`stream.topics.postProcess`. Topic partitions follow `postProcess.replicas.desired`
(default one). The worker accepts existing Go workload scheduling, security,
service-account, port and image-pull settings. Health probes use port 8080.

For SQS, set `stream.topics.postProcess.type: sqs`, `url` and `region`. Existing
stream credentials or per-topic credentials apply. SQS creates no Kafka topic
for post-processing. Required transport fields are validated before activation.

`postProcess.retryEnabled: true` separately enables the failed HTTP-callback
restart API. It requires queue support. Turning retry admission off preserves
recovery of already accepted work. The worker polls saved retry receipts through
the existing queue server, preserving backoff and live claims.

Before disabling queue support, stop retry admissions and new post-processing
work, then settle pending delivery, review, import and archive work. Keep the
compatible worker and queue available while draining. Existing installations
that used custom post-processing through the ordinary file queue must explicitly
enable this support when upgrading. Normal ingestion without custom
post-processing retains its existing queue.

Rendered configuration tests prove chart and Go configuration compatibility.
Image publication and deployment still require their release gates.
