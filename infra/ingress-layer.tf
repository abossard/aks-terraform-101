# Ingress Layer
# Application Gateway and NGINX Ingress Controller

# Public IP for Application Gateway
resource "azurerm_public_ip" "app_gateway" {
  name                = local.app_gateway_pip_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.common_tags
}

# Application Gateway
resource "azurerm_application_gateway" "main" {
  name                = local.app_gateway_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }

  waf_configuration {
    enabled                  = true
    firewall_mode            = "Prevention"
    rule_set_type            = "OWASP"
    rule_set_version         = "3.2"
    file_upload_limit_mb     = 100
    request_body_check       = true
    max_request_body_size_kb = 128
  }

  gateway_ip_configuration {
    name      = "appGatewayIpConfig"
    subnet_id = azurerm_subnet.app_gateway.id
  }

  frontend_port {
    name = "port_80"
    port = 80
  }

  frontend_port {
    name = "port_443"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "appGwPublicFrontendIp"
    public_ip_address_id = azurerm_public_ip.app_gateway.id
  }

  # Backend pool pointing to NGINX Ingress internal IP
  backend_address_pool {
    name         = "nginx-backend-pool"
    ip_addresses = [local.nginx_internal_ip]
  }

  backend_http_settings {
    name                  = "nginx-backend-http-settings"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
    probe_name            = "nginx-health-probe"

    connection_draining {
      enabled           = true
      drain_timeout_sec = 300
    }
  }

  backend_http_settings {
    name                  = "nginx-backend-https-settings"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 60
    probe_name            = "nginx-health-probe-https"

    connection_draining {
      enabled           = true
      drain_timeout_sec = 300
    }
  }

  # Health probes for NGINX Ingress
  probe {
    name                = "nginx-health-probe"
    protocol            = "Http"
    path                = "/healthz"
    host                = local.nginx_internal_ip
    port                = 80
    interval            = 30
    timeout             = 20
    unhealthy_threshold = 3

    match {
      status_code = ["200"]
    }
  }

  probe {
    name                = "nginx-health-probe-https"
    protocol            = "Https"
    path                = "/healthz"
    host                = local.nginx_internal_ip
    port                = 443
    interval            = 30
    timeout             = 20
    unhealthy_threshold = 3

    match {
      status_code = ["200"]
    }
  }

  http_listener {
    name                           = "appGwHttpListener"
    frontend_ip_configuration_name = "appGwPublicFrontendIp"
    frontend_port_name             = "port_80"
    protocol                       = "Http"
  }

  http_listener {
    name                           = "appGwHttpsListener"
    frontend_ip_configuration_name = "appGwPublicFrontendIp"
    frontend_port_name             = "port_443"
    protocol                       = "Https"
    ssl_certificate_name           = "app-gateway-ssl-cert"
  }

  # SSL Certificate from Key Vault (recommended for production)
  ssl_certificate {
    name                = "app-gateway-ssl-cert"
    key_vault_secret_id = "${azurerm_key_vault.main.vault_uri}secrets/ssl-certificate"
  }

  # Redirect HTTP to HTTPS
  redirect_configuration {
    name                 = "http-to-https-redirect"
    redirect_type        = "Permanent"
    target_listener_name = "appGwHttpsListener"
    include_path         = true
    include_query_string = true
  }

  request_routing_rule {
    name                        = "http-redirect-rule"
    rule_type                   = "Basic"
    http_listener_name          = "appGwHttpListener"
    redirect_configuration_name = "http-to-https-redirect"
    priority                    = 100
  }

  request_routing_rule {
    name                       = "https-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "appGwHttpsListener"
    backend_address_pool_name  = "nginx-backend-pool"
    backend_http_settings_name = "nginx-backend-https-settings"
    priority                   = 200
  }

  autoscale_configuration {
    min_capacity = 1
    max_capacity = 10
  }

  zones = ["1", "2", "3"]
  tags  = local.common_tags

  # Implicit dependency through SSL certificate reference
}

# NGINX Ingress Controller via Helm
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.10.0"

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.service.loadBalancerIP"
    value = local.nginx_internal_ip
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-internal"
    value = "true"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-internal-subnet"
    value = local.aks_subnet_name
  }

  set {
    name  = "controller.replicaCount"
    value = "3"
  }

  set {
    name  = "controller.nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }

  # Enable health check endpoint
  set {
    name  = "controller.healthStatus"
    value = "true"
  }

  set {
    name  = "controller.healthStatusURI"
    value = "/healthz"
  }

  # Configure resource limits
  set {
    name  = "controller.resources.limits.cpu"
    value = "500m"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "512Mi"
  }

  set {
    name  = "controller.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "128Mi"
  }

  # Configure metrics
  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }

  set {
    name  = "controller.metrics.serviceMonitor.enabled"
    value = "true"
  }

  # Configure admission webhook
  set {
    name  = "controller.admissionWebhooks.enabled"
    value = "true"
  }

  # Configure default backend
  set {
    name  = "defaultBackend.enabled"
    value = "true"
  }

  # Configure pod disruption budget
  set {
    name  = "controller.podDisruptionBudget.enabled"
    value = "true"
  }

  set {
    name  = "controller.podDisruptionBudget.minAvailable"
    value = "1"
  }

  # Implicit dependency through cluster connection in providers.tf
}

# Sample application to test the ingress
resource "kubernetes_deployment" "sample_app" {
  metadata {
    name      = "sample-app"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
    labels = {
      app = "sample-app"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "sample-app"
      }
    }

    template {
      metadata {
        labels = {
          app                           = "sample-app"
          "azure.workload.identity/use" = "true"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.workload_identity.metadata[0].name

        container {
          name  = "app"
          image = "nginx:1.21"

          port {
            container_port = 80
          }

          volume_mount {
            name       = "secrets-store"
            mount_path = "/mnt/secrets-store"
            read_only  = true
          }

          env {
            name  = "AZURE_CLIENT_ID"
            value = azurerm_user_assigned_identity.workload_identity.client_id
          }

          env {
            name  = "AZURE_TENANT_ID"
            value = data.azurerm_client_config.current.tenant_id
          }

          resources {
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        volume {
          name = "secrets-store"

          csi {
            driver    = "secrets-store.csi.k8s.io"
            read_only = true

            volume_attributes = {
              secretProviderClass = "azure-keyvault-secrets"
            }
          }
        }
      }
    }
  }

  # Implicit dependencies through namespace, service account, and helm release references
}

# Service for sample application
resource "kubernetes_service" "sample_app" {
  metadata {
    name      = "sample-app-service"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
  }

  spec {
    selector = {
      app = "sample-app"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }

  # Implicit dependency through deployment selector reference
}

# Ingress for sample application
resource "kubernetes_ingress_v1" "sample_app" {
  metadata {
    name      = "sample-app-ingress"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name

    annotations = {
      "kubernetes.io/ingress.class"                = "nginx"
      "nginx.ingress.kubernetes.io/rewrite-target" = "/"
      "nginx.ingress.kubernetes.io/ssl-redirect"   = "true"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.sample_app.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  # Implicit dependency through service reference
}