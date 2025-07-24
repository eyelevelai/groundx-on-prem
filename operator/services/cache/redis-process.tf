resource "helm_release" "redis_process" {
  count = local.create_cache ? 1 : 0

  name      = var.cache_internal.service
  namespace = var.app_internal.namespace

  chart     = "${local.module_path}/redis/helm_chart"

  values = [
    yamlencode({
      image = var.cache_internal.image
      image_repo_url = var.app_internal.repo_url
      nodeSelector = {
        node = local.node_assignment.cache
      }
      persistence = {
        mountPath = var.cache_internal.mount_path
      }
      replicas        = {
        max           = local.replicas.cache.max
        min           = local.replicas.cache.min
      }
      resources       = var.cache_resources.resources
      securityContext = {
        runAsUser  = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : 1001
        runAsGroup = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.GID, 1001) : 1001
        fsGroup    = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.GID, 1001) : 1001
      }
      service = {
        name         = var.cache_internal.service
        namespace    = var.app_internal.namespace
        port         = local.cache_settings.port
      }
    })
  ]
}