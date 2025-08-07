resource "helm_release" "upload_service" {
  name       = var.upload_internal.service
  namespace  = var.app_internal.namespace
  chart      = "${local.module_path}/upload/helm_chart"

  values = [
    yamlencode({
      busybox         = var.app_internal.busybox
      cluster         = var.cluster_arch
      dependencies    = {
        groundx       = "${var.groundx_internal.service}.${var.app_internal.namespace}.svc.cluster.local"
      }
      image           = {
        pull          = var.upload_internal.image.pull
        repository    = "${var.app_internal.repo_url}/${var.upload_internal.image.repository}${local.container_suffix}"
        tag           = var.upload_internal.image.tag
      }
      nodeSelector    = {
        node          = local.node_assignment.upload
      }
      replicas        = {
        cooldown      = var.upload_resources.replicas.cooldown
        max           = local.replicas.upload.max
        min           = local.replicas.upload.min
        threshold     = var.upload_resources.replicas.threshold
      }
      resources       = var.upload_resources.resources
      securityContext = {
        runAsUser     = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : 1001
        runAsGroup    = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.GID, 1001) : 1001
        fsGroup       = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.GID, 1001) : 1001
      }
      service         = {
        name          = var.upload_internal.service
        namespace     = var.app_internal.namespace
        version       = var.upload_internal.version
      }
    })
  ]
}