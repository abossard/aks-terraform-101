# Ingress Layer
# Application Gateway and NGINX Ingress Controller

# Public IP for Application Gateway
resource "azurerm_public_ip" "app_gateway" {
  name                = local.app_gateway_pip_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]
  tags                = local.common_tags
}

# User-Assigned Managed Identity for Application Gateway
resource "azurerm_user_assigned_identity" "app_gateway" {
  name                = "id-agw-${var.environment}-${var.location_code}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

# Grant Application Gateway identity access to Key Vault
resource "azurerm_role_assignment" "app_gateway_key_vault" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app_gateway.principal_id
}

# Application Gateway
resource "azurerm_application_gateway" "main" {
  name                = local.app_gateway_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
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

  # SSL Certificate from PKCS#12 data using auto-generated password
  ssl_certificate {
    name     = "app-gateway-ssl-cert"
    data     = pkcs12_from_pem.app_gateway.result
    password = random_password.ssl_cert_password.result
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

  zones = ["1"]
  tags  = local.common_tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app_gateway.id]
  }

  # Implicit dependency through SSL certificate reference
}

# Kubernetes resources removed - deploy manually after infrastructure
# Use the following commands after infrastructure deployment:
# 1. helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
# 2. helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace
# 3. Deploy sample applications and configure ingress resources