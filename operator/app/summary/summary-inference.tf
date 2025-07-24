resource "helm_release" "summary_inference_service" {
  count = local.create_summary ? 1 : 0

  name       = "${var.summary_internal.service}-inference"
  namespace  = var.app_internal.namespace

  chart      = "${local.module_path}/summary/inference/helm_chart"

  timeout    = 1800

  values = [
    yamlencode({
      busybox             = var.app_internal.busybox
      createSymlink       = local.create_symlink ? true : false
      dependencies        = {
        cache             = "${local.cache_settings.addr} ${local.cache_settings.port}"
      }
      image               = {
        pull              = var.summary_internal.inference.image.pull
        repository        = "${var.app_internal.repo_url}/${var.summary_internal.inference.image.repository}${local.op_container_suffix}"
        tag               = var.summary_internal.inference.image.tag
      }
      local               = var.cluster.environment == "local"
      nodeSelector        = {
        node              = local.node_assignment.summary_inference
      }
      pv                  = {
        access            = var.summary_internal.inference.pv.access
        capacity          = var.summary_internal.inference.pv.capacity
        name              = "${var.summary_internal.service}-model"
        storage           = var.cluster.pv.name
      }
      replicas            = {
        cooldown          = var.summary_resources.inference.replicas.cooldown
        max               = local.replicas.summary.inference.max
        min               = local.replicas.summary.inference.min
        threshold         = var.summary_resources.inference.replicas.threshold
      }
      resources           = var.summary_resources.inference.resources
      securityContext     = {
        fsGroup           = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : 1001
        runAsUser         = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : 1001
        runAsGroup        = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : 1001
      }
      service = {
        name              = "${var.summary_internal.service}-inference"
        namespace         = var.app_internal.namespace
        version           = var.summary_internal.version
      }
      type                = var.cluster.type
      waitForDependencies = true
    })
  ]
}