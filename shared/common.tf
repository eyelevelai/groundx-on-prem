provider "kubernetes" {
  config_path = var.cluster.kube_config_path
}

locals {
  baseline_ingest = var.cluster.throughput.ingest.baseline
  baseline_search = var.cluster.throughput.search.baseline

  max_ingest = var.cluster.throughput.ingest.max
  max_search = var.cluster.throughput.search.max

  replicas = {
    cache = {
      max = var.cache_resources.replicas
      min = var.cache_resources.replicas
      node = local.node_assignment.cache
      resources = var.cache_resources.resources
    }
    db = {
      operator = {
        max = var.db_resources.replicas
        min = var.db_resources.replicas
        node = local.node_assignment.db
        resources = var.db_resources.resources
      }
      proxy = {
        max = var.db_resources.proxy.replicas
        min = var.db_resources.proxy.replicas
        node = local.node_assignment.db
        resources = var.db_resources.proxy.resources
      }
    }
    file = {
      max = var.file_resources.pool_servers
      min = var.file_resources.pool_servers
      node = local.node_assignment.file
      resources = var.file_resources.resources
    }
    groundx = {
      max = max(3, ceil(local.max_ingest / var.groundx_resources.throughput))
      min = max(1, ceil(local.baseline_ingest / var.groundx_resources.throughput))
      node = local.node_assignment.groundx
      resources = var.groundx_resources.resources
    }
    layout = {
      api = {
        max = max(3, ceil(local.max_ingest / var.layout_resources.api.throughput))
        min = max(1, ceil(local.baseline_ingest / var.layout_resources.api.throughput))
        node = local.node_assignment.layout_api
        resources = var.layout_resources.api.resources
      }
      correct = {
        max = max(3, ceil(local.max_ingest / var.layout_resources.correct.throughput))
        min = max(1, ceil(local.baseline_ingest / var.layout_resources.correct.throughput))
        node = local.node_assignment.layout_correct
        resources = var.layout_resources.correct.resources
      }
      inference = {
        max = max(3, ceil(local.max_ingest / var.layout_resources.inference.throughput))
        min = max(1, ceil(local.baseline_ingest / var.layout_resources.inference.throughput))
        node = local.node_assignment.layout_inference
        resources = var.layout_resources.inference.resources
      }
      map = {
        max = max(3, ceil(local.max_ingest / var.layout_resources.map.throughput))
        min = max(1, ceil(local.baseline_ingest / var.layout_resources.map.throughput))
        node = local.node_assignment.layout_map
        resources = var.layout_resources.map.resources
      }
      ocr = {
        max = max(3, ceil(local.max_ingest / var.layout_resources.ocr.throughput))
        min = max(1, ceil(local.baseline_ingest / var.layout_resources.ocr.throughput))
        node = local.node_assignment.layout_ocr
        resources = var.layout_resources.ocr.resources
      }
      process = {
        max = max(3, ceil(local.max_ingest / var.layout_resources.process.throughput))
        min = max(1, ceil(local.baseline_ingest / var.layout_resources.process.throughput))
        node = local.node_assignment.layout_process
        resources = var.layout_resources.process.resources
      }
      save = {
        max = max(3, ceil(local.max_ingest / var.layout_resources.save.throughput))
        min = max(1, ceil(local.baseline_ingest / var.layout_resources.save.throughput))
        node = local.node_assignment.layout_save
        resources = var.layout_resources.save.resources
      }
    }
    layout_webhook = {
      max = max(3, ceil(local.max_ingest / var.layout_webhook_resources.throughput))
      min = max(1, ceil(local.baseline_ingest / var.layout_webhook_resources.throughput))
      node = local.node_assignment.layout_webhook
      resources = var.layout_webhook_resources.resources
    }
    pre_process = {
      max = max(3, ceil(local.max_ingest / var.pre_process_resources.throughput))
      min = max(1, ceil(local.baseline_ingest / var.pre_process_resources.throughput))
      node = local.node_assignment.pre_process
      resources = var.pre_process_resources.resources
    }
    process = {
      max = max(3, ceil(local.max_ingest / var.process_resources.throughput))
      min = max(1, ceil(local.baseline_ingest / var.process_resources.throughput))
      node = local.node_assignment.process
      resources = var.process_resources.resources
    }
    queue = {
      max = max(3, ceil(local.max_ingest / var.queue_resources.throughput))
      min = max(1, ceil(local.baseline_ingest / var.queue_resources.throughput))
      node = local.node_assignment.queue
      resources = var.queue_resources.resources
    }
    ranker = {
      api = {
        max = max(3, ceil(local.max_search / var.ranker_resources.api.throughput))
        min = max(1, ceil(local.baseline_search / var.ranker_resources.api.throughput))
        node = local.node_assignment.ranker_api
        resources = var.ranker_resources.api.resources
      }
      inference = {
        max = max(3, ceil(local.max_search / var.ranker_resources.inference.throughput))
        min = max(1, ceil(local.baseline_search / var.ranker_resources.inference.throughput))
        node = local.node_assignment.ranker_inference
        resources = var.ranker_resources.inference.resources
      }
    }
    search = {
      max = var.search_resources.replicas
      min = var.search_resources.replicas
      node = local.node_assignment.search
      resources = var.search_resources.resources
    }
    stream = {
      max = var.stream_resources.service.replicas
      min = var.stream_resources.service.replicas
      node = local.node_assignment.stream
      resources = var.stream_resources.resources
    }
    summary = {
      api = {
        max = var.cluster_arch.summary.api > 0 ? var.cluster_arch.summary.api : max(3, ceil(local.max_ingest / var.summary_resources.api.throughput))
        min = var.cluster_arch.summary.api > 0 ? var.cluster_arch.summary.api : max(1, ceil(local.baseline_ingest / var.summary_resources.api.throughput))
        node = local.node_assignment.summary_api
        resources = var.summary_resources.api.resources
      }
      inference = {
        max = var.cluster_arch.summary.inference > 0 ? var.cluster_arch.summary.inference : max(3, ceil(local.max_ingest / var.summary_resources.inference.throughput))
        min = var.cluster_arch.summary.inference > 0 ? var.cluster_arch.summary.inference : max(1, ceil(local.baseline_ingest / var.summary_resources.inference.throughput))
        node = local.node_assignment.summary_inference
        resources = var.summary_resources.inference.resources
      }
    }
    summary_client = {
      max = var.cluster_arch.summary.client > 0 ? var.cluster_arch.summary.client : max(3, ceil(local.max_ingest / var.summary_client_resources.throughput))
      min = var.cluster_arch.summary.client > 0 ? var.cluster_arch.summary.client : max(1, ceil(local.baseline_ingest / var.summary_client_resources.throughput))
      node = local.node_assignment.summary_client
      resources = var.summary_client_resources.resources
    }
    upload = {
      max = max(3, ceil(local.max_ingest / var.upload_resources.throughput))
      min = max(1, ceil(local.baseline_ingest / var.upload_resources.throughput))
      node = local.node_assignment.upload
      resources = var.upload_resources.resources
    }
  }
}