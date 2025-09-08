resource "kubernetes_namespace" "eyelevel" {
  metadata {
    name = var.app_internal.namespace
  }
}

resource "tls_private_key" "ca_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ca_cert" {
  depends_on = [tls_private_key.ca_key]

  private_key_pem = tls_private_key.ca_key.private_key_pem
  subject {
    common_name  = "Self-Signed Cluster Root CA"
    organization = var.app_internal.namespace
  }

  validity_period_hours = 87600  # 10 years
  early_renewal_hours   = 720    # 30 days
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing"
  ]
}

resource "tls_private_key" "service_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "service_csr" {
  depends_on = [tls_private_key.service_key]

  private_key_pem = tls_private_key.service_key.private_key_pem

  subject {
    common_name  = "*.${var.app_internal.namespace}.svc"
    organization = var.app_internal.namespace
  }

  dns_names             = ["*.${var.app_internal.namespace}.svc"]
}

resource "tls_locally_signed_cert" "service_cert" {
  depends_on = [tls_cert_request.service_csr, tls_private_key.ca_key, tls_self_signed_cert.ca_cert]

  cert_request_pem      = tls_cert_request.service_csr.cert_request_pem
  ca_private_key_pem    = tls_private_key.ca_key.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca_cert.cert_pem

  validity_period_hours = 8760  # 1 year
  early_renewal_hours   = 720   # 30 days

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth"
  ]
}

resource "kubernetes_secret" "ssl_cert" {
  depends_on = [tls_locally_signed_cert.service_cert, kubernetes_namespace.eyelevel]

  metadata {
    name      = "${var.app_internal.namespace}-cert"
    namespace = var.app_internal.namespace
  }

  data = {
    "tls.crt" = tls_locally_signed_cert.service_cert.cert_pem
    "tls.key" = tls_private_key.service_key.private_key_pem
    "ca.crt"  = tls_self_signed_cert.ca_cert.cert_pem
  }

  type = "kubernetes.io/tls"
}