resource "kubernetes_service" "loadbalancer" {
  metadata {
    name = var.groundx_lb_service
  }

  spec {
    selector = {
      app = var.groundx_service
    }

    port {
      port = var.groundx_lb_port
    }
  }
}
