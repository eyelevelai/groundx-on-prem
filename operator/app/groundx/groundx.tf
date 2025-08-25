locals {
  gx_image_tag = var.groundx_internal.image.tag != "latest" ? var.groundx_internal.image.tag : var.deployment_type.tag
}

resource "helm_release" "groundx_service" {
  name       = var.groundx_internal.service
  namespace  = var.app_internal.namespace
  chart      = "${local.module_path}/groundx/helm_chart"

  values = [
    yamlencode({
      busybox         = var.app_internal.busybox
      cluster         = var.cluster_arch
      dependencies    = {
        cache         = "${local.cache_settings.addr} ${local.cache_settings.port}"
        database      = "${local.db_endpoints.ro} ${local.db_endpoints.port}"
        file          = "${local.file_settings.dependency} ${local.file_settings.port}"
        search        = "${local.search_settings.base_domain} ${local.search_settings.port}"
        stream        = "${local.stream_settings.base_domain} ${local.stream_settings.port}"
      }
      image           = {
        pull          = var.groundx_internal.image.pull
        repository    = "${var.app_internal.repo_url}/${var.groundx_internal.image.repository}${local.container_suffix}"
        tag           = local.gx_image_tag
      }
      ingestOnly      = local.ingest_only
      nodeSelector    = {
        node          = local.node_assignment.groundx
      }
      replicas        = {
        cooldown      = var.groundx_resources.replicas.cooldown
        max           = local.replicas.groundx.max
        min           = local.replicas.groundx.min
        threshold     = var.groundx_resources.replicas.threshold
      }
      resources       = var.groundx_resources.resources
      securityContext = {
        runAsUser     = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : var.deployment_type.user != null ? var.deployment_type.user : 1001
        runAsGroup    = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.GID, 1001) : var.deployment_type.user != null ? var.deployment_type.user : 1001
        fsGroup       = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.GID, 1001) : var.deployment_type.user != null ? var.deployment_type.user : 1001
      }
      service         = {
        name          = var.groundx_internal.service
        namespace     = var.app_internal.namespace
      }
      username        = local.gx_image_tag == "chainguard" ? "nonroot" : "golang"
    })
  ]

  timeout = 300
}