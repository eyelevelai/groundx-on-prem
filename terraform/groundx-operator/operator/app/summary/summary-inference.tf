locals {
  si_image_tag = var.summary_internal.inference.image.tag != "latest" ? var.summary_internal.inference.image.tag : var.deployment_type.tag
}

resource "helm_release" "summary_inference_service" {
  count = local.create_summary ? 1 : 0

  name       = "${var.summary_internal.service}-inference"
  namespace  = var.app_internal.namespace

  chart      = "${local.module_path}/summary/inference/helm_chart"

  timeout    = 1800

  disable_openapi_validation = var.cluster.type == "openshift"

  values = [
    yamlencode({
      busybox             = var.app_internal.busybox
      cluster             = var.cluster_arch
      createSymlink       = local.create_symlink ? true : false
      dependencies        = {
        cache             = "${local.cache_settings.addr} ${local.cache_settings.port}"
      }
      image               = {
        pull              = var.summary_internal.inference.image.pull
        repository        = "${var.app_internal.repo_url}/${var.summary_internal.inference.image.repository}${local.op_container_suffix}"
        tag               = local.si_image_tag
      }
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
      runtime             = var.cluster.type == "aks" ? "nvidia-container-runtime" : "nvidia"
      securityContext     = {
        fsGroup           = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : var.deployment_type.user != null ? var.deployment_type.user : 1001
        runAsUser         = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : var.deployment_type.user != null ? var.deployment_type.user : 1001
        runAsGroup        = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : var.deployment_type.user != null ? var.deployment_type.user : 1001
      }
      service             = {
        name              = "${var.summary_internal.service}-inference"
        namespace         = var.app_internal.namespace
        version           = var.summary_internal.version
      }
      type                = var.cluster.type
      waitForDependencies = true
    })
  ]
}