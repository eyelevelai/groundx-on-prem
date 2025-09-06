resource "helm_release" "groundx_lb" {
  count = local.is_openshift ? 0 : 1

  depends_on = [helm_release.groundx_service]

  name       = "${var.groundx_internal.service}-service"
  namespace  = var.app_internal.namespace
  chart      = "${local.module_path}/scaling/load-balancer/helm_chart"

  values = [
    yamlencode({
      internal   = var.groundx.load_balancer.internal
      name       = "${var.groundx_internal.service}-service"
      namespace  = var.app_internal.namespace
      port       = var.groundx.load_balancer.port
      target     = var.groundx_internal.service
      targetPort = var.groundx.load_balancer.target
    })
  ]
}

resource "helm_release" "groundx_route" {
  count = local.is_openshift ? 1 : 0

  depends_on = [helm_release.groundx_service]

  name       = "${var.groundx_internal.service}-service"
  namespace  = var.app_internal.namespace
  chart      = "${local.module_path}/scaling/route/helm_chart"

  values = [
    yamlencode({
      name       = "${var.groundx_internal.service}-service"
      namespace  = var.app_internal.namespace
      port       = var.groundx.load_balancer.port
      target     = var.groundx_internal.service
      targetPort = var.groundx.load_balancer.target
    })
  ]
}