resource "helm_release" "summary_api_lb" {
  count = local.create_summary ? 1 : 0

  depends_on = [helm_release.summary_api_service]

  name       = "${var.summary_internal.service}-service"
  namespace  = var.app_internal.namespace
  chart      = "${local.module_path}/scaling/load-balancer/helm_chart"

  values = [
    yamlencode({
      internal  = var.summary_resources.load_balancer.internal
      name      = "${var.summary_internal.service}-service"
      namespace = var.app_internal.namespace
      port      = var.summary_resources.load_balancer.port
      target    = "${var.summary_internal.service}-api"
      timeout   = 240
    })
  ]
}