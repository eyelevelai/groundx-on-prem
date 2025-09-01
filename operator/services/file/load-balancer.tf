resource "helm_release" "minio_lb" {
  count = local.is_openshift ?  0 : (var.file_internal.load_balancer != null ? 1 : 0)

  depends_on = [helm_release.minio_tenant]

  name       = "${var.file_internal.service}-service"
  namespace  = var.app_internal.namespace
  chart      = "${local.module_path}/scaling/load-balancer/helm_chart"

  values = [
    yamlencode({
      internal   = var.file_internal.load_balancer.internal
      name       = "${var.file_internal.service}-service"
      namespace  = var.app_internal.namespace
      port       = var.file_internal.load_balancer.port
      target     = var.file_internal.service
      targetPort = var.file_internal.load_balancer.target
    })
  ]
}

resource "helm_release" "minio_route" {
  count = local.is_openshift ? (var.file_internal.load_balancer != null ? 1 : 0) : 0

  depends_on = [helm_release.minio_tenant]

  name       = "${var.file_internal.service}-service"
  namespace  = var.app_internal.namespace
  chart      = "${local.module_path}/scaling/route/helm_chart"

  values = [
    yamlencode({
      name       = "${var.file_internal.service}-service"
      namespace  = var.app_internal.namespace
      port       = var.file_internal.load_balancer.port
      target     = var.file_internal.service
      targetPort = var.file_internal.load_balancer.target
    })
  ]
}