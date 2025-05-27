locals {
  config_yaml = templatefile(
    "${local.module_path}/config/config.yaml.tpl", {
    cacheAddr              = local.cache_settings.addr
    cacheNotCluster        = local.cache_settings.is_instance
    cachePort              = local.cache_settings.port
    dashboardService       = var.dashboard_internal.service
    dbCreateDBPassword     = local.db_settings.db_create_db_password
    dbCreateDBUser         = local.db_settings.db_create_db_username
    dbName                 = local.db_settings.db_name
    dbRO                   = local.db_endpoints.ro
    dbRW                   = local.db_endpoints.rw
    dbServiceUser          = local.db_settings.db_service_username
    dbServiceUserPassword  = local.db_settings.db_service_password
    deploymentType         = var.groundx_internal.type
    documentTPM            = var.throughput.conversions.document.tpm
    engineCount            = length(var.engines)
    engines                = jsonencode(var.engines)
    fileBaseDomain         = local.file_settings.base_domain
    filePassword           = local.file_settings.password
    fileService            = var.file_internal.service
    fileSSL                = local.file_settings.ssl
    fileUsername           = local.file_settings.username
    groundxService         = var.groundx_internal.service
    groundxServiceKey      = var.admin.api_key
    groundxUsername        = var.admin.username
    ingestOnly             = local.ingest_only
    languages              = jsonencode(var.app.languages)
    layoutService          = "${var.layout_internal.service}-api"
    layoutWebhookService   = var.layout_webhook_internal.service
    metrics                = {
      api                  = jsonencode([
        {
          name             = "${var.groundx_internal.service}",
        },
        {
          name             = "${var.layout_internal.service}-api",
        },
        {
          name             = "${var.layout_webhook_internal.service}",
        }
      ])
      cacheAddr            = local.metrics_cache_settings.addr
      cacheNotCluster      = local.metrics_cache_settings.is_instance
      cachePort            = local.metrics_cache_settings.port
      documentTPM          = var.throughput.conversions.document.tpm
      inference            = jsonencode([
        {
          name             = "${var.layout_internal.service}-inference",
          tokensPerMinute  = var.throughput.services.layout.inference,
        },
        {
          name             = "${var.summary_internal.service}-api",
          tokensPerMinute  = var.throughput.services.summary.api,
        },
        {
          name             = "${var.summary_internal.service}-inference",
          tokensPerMinute  = var.throughput.services.summary.inference,
        },
        {
          name             = var.summary_client_internal.service,
          tokensPerMinute  = var.throughput.services.summary_client.api,
        },
      ])
      pageTPM              = var.throughput.conversions.page.tpm
      queue                = jsonencode([
        {
          name             = "${var.pre_process_internal.service}",
          target           = var.pre_process_internal.queue,
          threshold        = var.throughput.services.pre_process.queue,
        },
        {
          name             = "${var.process_internal.service}",
          target           = var.process_internal.queue,
          threshold        = var.throughput.services.process.queue,
        },
        {
          name             = "${var.queue_internal.service}",
          target           = var.queue_internal.queue,
          threshold        = var.throughput.services.queue.queue,
        },
        {
          name             = "${var.upload_internal.service}",
          target           = var.upload_internal.queue,
          threshold        = var.throughput.services.upload.queue,
        },
      ])
      service              = var.metrics_internal.service
      summaryRequestTPM    = var.throughput.conversions.summaryRequests.tpm
      task                 = jsonencode([
        {
          name             = "${var.layout_internal.service}-map",
          target           = var.layout_internal.map.queues,
          threshold        = var.throughput.services.layout.map,
        },
        {
          name             = "${var.layout_internal.service}-ocr",
          target           = var.layout_internal.ocr.queues,
          threshold        = var.throughput.services.layout.ocr,
        },
        {
          name             = "${var.layout_internal.service}-process",
          target           = var.layout_internal.process.queues,
          threshold        = var.throughput.services.layout.process,
        },
        {
          name             = "${var.layout_internal.service}-save",
          target           = var.layout_internal.save.queues,
          threshold        = var.throughput.services.layout.save,
        },
      ])
    }
    namespace              = var.app_internal.namespace
    queueQueue             = var.queue_internal.queue
    queueQueueSize         = var.queue_resources.queue_size
    preProcessQueue        = var.pre_process_internal.queue
    preProcessQueueSize    = var.pre_process_resources.queue_size
    preProcessService      = var.pre_process_internal.service
    processQueue           = var.process_internal.queue
    processQueueSize       = var.process_resources.queue_size
    processService         = var.process_internal.service
    queueService           = var.queue_internal.service
    rankerService          = "${var.ranker_internal.service}-api"
    searchBaseUrl          = local.search_settings.base_url
    searchIndex            = var.search.index
    searchPassword         = var.search.password
    searchRootPassword     = var.search.root_password
    searchUser             = var.search.user
    sslCACert              = "/etc/ssl/tls/ca.crt"
    sslCert                = "/etc/ssl/tls/tls.crt"
    sslKey                 = "/etc/ssl/tls/tls.key"
    streamBaseUrl          = "${local.stream_settings.base_domain}:${local.stream_settings.port}"
    streamService          = var.stream_internal.service
    summaryApiKey          = local.summary_credentials.api_key
    summaryBaseUrl         = local.summary_credentials.base_url
    summaryClientQueue     = var.summary_client_internal.queue
    summaryClientService   = var.summary_client_internal.service
    summaryClientWorkers   = var.summary_client_resources.workers
    summaryEngineType      = local.summary_credentials.service_type
    summaryService         = var.summary_internal.service
    uploadBucket           = local.file_settings.bucket
    uploadQueue            = var.upload_internal.queue
    uploadQueueSize        = var.upload_resources.queue_size
    uploadService          = var.upload_internal.service
  })
}

resource "kubernetes_config_map" "cashbot_config_file" {
  metadata {
    name      = "config-yaml-map"
    namespace = var.app_internal.namespace
  }

  data = {
    "config.yaml" = local.config_yaml
  }
}