resource "helm_release" "strimzi_operator" {
  count = local.create_stream ? 1 : 0

  name       = "${var.stream_internal.service}-operator"
  namespace  = var.app_internal.namespace
  chart      = var.stream_internal.chart.url
  version    = var.stream_internal.chart.version

  values = [
    yamlencode({
      nodeSelector = var.app.node_selector ? {
        node = local.node_assignment.stream
      } : {}
      replicas = var.stream_resources.operator.replicas
    })
  ]
}

resource "helm_release" "kafka_cluster" {
  count = local.create_stream ? 1 : 0

  depends_on = [helm_release.strimzi_operator]

  name       = "${var.stream_internal.service}-cluster"
  namespace  = var.app_internal.namespace
  chart      = "${local.module_path}/kafka/helm_chart"

  values = [
    yamlencode({
      nodeSelector = var.app.node_selector ? {
        node = local.node_assignment.stream
      } : {}
      partitions = {
        pre_process    = local.replicas.pre_process.max
        process        = local.replicas.process.max
        queue          = local.replicas.queue.max
        summary_client = local.replicas.summary_client.max
        upload         = local.replicas.upload.max
      }
      resources = var.stream_resources.resources
      service = {
        meta_version    = var.stream_internal.meta_version
        name            = var.stream_internal.service
        namespace       = var.app_internal.namespace
        port            = var.stream_internal.port
        replicas        = var.stream_resources.service.replicas
        retention_bytes = var.stream_resources.retention_bytes
        segment_bytes   = var.stream_resources.segment_bytes
        storage    = {
          size = var.stream_resources.service.storage
        }
        version = var.stream_internal.version
      }
      nodepool = {
        replicas = var.stream_resources.nodepool.replicas
        storage  = {
          size = var.stream_resources.nodepool.storage
        }
      }
    })
  ]
}

resource "null_resource" "wait_for_entity_operator" {
  count = local.create_stream ? 1 : 0

  depends_on = [helm_release.kafka_cluster]

  provisioner "local-exec" {
    command = <<EOT
#!/bin/bash
echo "Waiting for Entity Operator..."
while true; do
  # Check if at least one pod with the label 'name=entity-operator' is running and ready
  STATUS=$(kubectl get pods -n ${var.app_internal.namespace} -l strimzi.io/name=${var.stream_internal.service}-cluster-entity-operator -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
  READY=$(kubectl get pods -n ${var.app_internal.namespace} -l strimzi.io/name=${var.stream_internal.service}-cluster-entity-operator -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)
  if [ "$STATUS"=="Running" ] && [ "$READY"=="true" ]; then
    echo "Entity Operator is ready."
    break
  else
    echo "Waiting for Entity Operator to be ready..."
    sleep 5
  fi
done
EOT
  }
}

resource "helm_release" "kafka_topics" {
  count = local.create_stream ? 1 : 0

  depends_on = [null_resource.wait_for_entity_operator]

  name       = "${var.stream_internal.service}-topics"
  namespace  = var.app_internal.namespace
  chart      = "${local.module_path}/kafka_topics/helm_chart"

  values = [
    yamlencode({
      partitions = {
        pre_process    = local.replicas.pre_process.max
        process        = local.replicas.process.max
        queue          = local.replicas.queue.max
        summary_client = local.replicas.summary_client.max
        upload         = local.replicas.upload.max
      }
      service = {
        name            = var.stream_internal.service
        replicas        = var.stream_resources.service.replicas
        retention_bytes = var.stream_resources.retention_bytes
        segment_bytes   = var.stream_resources.segment_bytes
      }
      topics = {
        pre_process    = var.pre_process_internal.queue
        process        = var.process_internal.queue
        queue          = var.queue_internal.queue
        summary_client = var.summary_client_internal.queue
        upload         = var.upload_internal.queue
      }
    })
  ]
}