locals {
  layout_config = templatefile(
    "${local.module_path}/layout/config.py.tpl", {
    cacheAddr        = local.cache_settings.addr
    cachePort        = local.cache_settings.port
    deviceType       = var.layout_internal.models.device
    fileBaseDomain   = local.file_settings.base_domain
    fileBucketDomain = local.file_settings.bucket_domain
    fileBucketSSL    = local.file_settings.bucket_ssl
    filePassword     = local.file_settings.password
    fileService      = var.file_internal.service
    fileSSL          = local.file_settings.ssl
    fileUsername     = local.file_settings.username
    metricsAddr      = local.metrics_cache_settings.addr
    metricsPort      = local.metrics_cache_settings.port
    minBatchSize     = var.layout_process_batch_size
    namespace        = var.app_internal.namespace
    layoutService    = var.layout_internal.service
    ocrProject       = var.layout.ocr.project
    ocrType          = var.layout.ocr.type
    podMemory        = var.layout_resources.process.resources.requests.memory
    uploadBucket     = local.file_settings.bucket
    validAPIKey      = var.admin.api_key
    validUsername    = var.admin.username
    workers          = var.layout_resources.inference.workers
  })

  layout_gunicorn = templatefile(
    "${local.module_path}/layout/gunicorn_conf.py.tpl", {
    threads = var.layout_resources.api.threads
    workers = var.layout_resources.api.workers
  })

  layout_ocr_data = var.layout.ocr.credentials != "" ? file("${path.module}/../../../${var.layout.ocr.credentials}") : ""

  layout_correct_supervisord = "${
    file(
      "${local.module_path}/layout/supervisord.base.conf.tpl"
    )
  }\n${
    join(
      "\n",
      [
        for i in range(var.layout_resources.map.workers) : templatefile("${local.module_path}/layout/supervisord.process.conf.tpl", {
          queues         = var.layout_internal.correct.queues
          threads        = var.layout_resources.map.threads
          worker_number  = i + 1
        })
      ]
    )
  }"

  layout_inference_supervisord = "${
    file(
      "${local.module_path}/layout/supervisord.base.conf.tpl"
    )
  }\n${
    join(
      "\n",
      [
        for i in range(var.layout_resources.inference.workers) : templatefile("${local.module_path}/layout/supervisord.inference.conf.tpl", {
          queues        = var.layout_internal.inference.queues
          threads       = var.layout_resources.inference.threads
          worker_number = i + 1
        })
      ]
    )
  }"

  layout_map_supervisord = "${
    file(
      "${local.module_path}/layout/supervisord.base.conf.tpl"
    )
  }\n${
    join(
      "\n",
      [
        for i in range(var.layout_resources.map.workers) : templatefile("${local.module_path}/layout/supervisord.process.conf.tpl", {
          queues         = var.layout_internal.map.queues
          threads        = var.layout_resources.map.threads
          worker_number  = i + 1
        })
      ]
    )
  }"

  layout_ocr_supervisord = "${
    file(
      "${local.module_path}/layout/supervisord.base.conf.tpl"
    )
  }\n${
    join(
      "\n",
      [
        for i in range(var.layout_resources.ocr.workers) : templatefile("${local.module_path}/layout/supervisord.process.conf.tpl", {
          queues        = var.layout_internal.ocr.queues
          threads       = var.layout_resources.ocr.threads
          worker_number = i + 1
        })
      ]
    )
  }"

  layout_process_supervisord = "${
    file(
      "${local.module_path}/layout/supervisord.base.conf.tpl"
    )
  }\n${
    join(
      "\n",
      [
        for i in range(var.layout_resources.process.workers) : templatefile("${local.module_path}/layout/supervisord.process.conf.tpl", {
          queues         = var.layout_internal.process.queues
          threads        = var.layout_resources.process.threads
          worker_number  = i + 1
        })
      ]
    )
  }"

  layout_save_supervisord = "${
    file(
      "${local.module_path}/layout/supervisord.base.conf.tpl"
    )
  }\n${
    join(
      "\n",
      [
        for i in range(var.layout_resources.save.workers) : templatefile("${local.module_path}/layout/supervisord.process.conf.tpl", {
          queues         = var.layout_internal.save.queues
          threads        = var.layout_resources.save.threads
          worker_number  = i + 1
        })
      ]
    )
  }"
}

resource "kubernetes_config_map" "layout_config_file" {
  metadata {
    name      = "layout-config-py-map"
    namespace = var.app_internal.namespace
  }

  data = {
    "config.py" = local.layout_config
  }
}

resource "kubernetes_config_map" "layout_gunicorn_conf_file" {
  metadata {
    name      = "layout-gunicorn-conf-py-map"
    namespace = var.app_internal.namespace
  }

  data = {
    "gunicorn_conf.py" = local.layout_gunicorn
  }
}

resource "kubernetes_config_map" "layout_ocr_credentials" {
  metadata {
    name      = "layout-ocr-credentials-map"
    namespace = var.app_internal.namespace
  }

  data = {
    "credentials.json" = local.layout_ocr_data
  }
}

resource "kubernetes_config_map" "layout_correct_supervisord_conf" {
  metadata {
    name      = "layout-correct-supervisord-conf-map"
    namespace = var.app_internal.namespace
  }

  data = {
    "supervisord.conf" = local.layout_correct_supervisord
  }
}

resource "kubernetes_config_map" "layout_inference_supervisord_16gb_conf" {
  metadata {
    name      = "layout-inference-supervisord-16gb-conf-map"
    namespace = var.app_internal.namespace
  }

  data = {
    "supervisord.conf" = local.layout_inference_supervisord
  }
}

resource "kubernetes_config_map" "layout_map_supervisord_conf" {
  metadata {
    name      = "layout-map-supervisord-conf-map"
    namespace = var.app_internal.namespace
  }

  data = {
    "supervisord.conf" = local.layout_map_supervisord
  }
}

resource "kubernetes_config_map" "layout_ocr_supervisord_conf" {
  metadata {
    name      = "layout-ocr-supervisord-conf-map"
    namespace = var.app_internal.namespace
  }

  data = {
    "supervisord.conf" = local.layout_ocr_supervisord
  }
}

resource "kubernetes_config_map" "layout_process_supervisord_conf" {
  metadata {
    name      = "layout-process-supervisord-conf-map"
    namespace = var.app_internal.namespace
  }

  data = {
    "supervisord.conf" = local.layout_process_supervisord
  }
}

resource "kubernetes_config_map" "layout_save_supervisord_conf" {
  metadata {
    name      = "layout-save-supervisord-conf-map"
    namespace = var.app_internal.namespace
  }

  data = {
    "supervisord.conf" = local.layout_save_supervisord
  }
}