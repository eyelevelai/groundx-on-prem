locals {
  la_image_tag = var.layout_internal.api.image.tag != "latest" ? var.layout_internal.api.image.tag : var.deployment_type.tag
}

resource "helm_release" "layout_api_service" {
  name       = "${var.layout_internal.service}-api"
  namespace  = var.app_internal.namespace

  chart      = "${local.module_path}/layout/api/helm_chart"

  disable_openapi_validation = var.cluster.type == "openshift"

  values = [
    yamlencode({
      busybox         = var.app_internal.busybox
      cluster         = var.cluster_arch
      dependencies    = {
        cache         = "${local.cache_settings.addr} ${local.cache_settings.port}"
      }
      image           = {
        pull          = var.layout_internal.api.image.pull
        repository    = "${var.app_internal.repo_url}/${var.layout_internal.api.image.repository}${local.container_suffix}"
        tag           = local.la_image_tag
      }
      nodeSelector    = {
        node          = local.node_assignment.layout_api
      }
      replicas        = {
        cooldown      = var.layout_resources.api.replicas.cooldown
        max           = local.replicas.layout.api.max
        min           = local.replicas.layout.api.min
        threshold     = var.layout_resources.api.replicas.threshold
      }
      resources       = var.layout_resources.api.resources
      securityContext = {
        fsGroup       = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : var.deployment_type.user != null ? var.deployment_type.user : 1001
        runAsGroup    = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : var.deployment_type.user != null ? var.deployment_type.user : 1001
        runAsUser     = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : var.deployment_type.user != null ? var.deployment_type.user : 1001
      }
      service         = {
        name          = "${var.layout_internal.service}-api"
        namespace     = var.app_internal.namespace
        version       = var.layout_internal.version
      }
    })
  ]

  timeout = 300
}