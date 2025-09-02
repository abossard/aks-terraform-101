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

  # Apply WAF policy
  firewall_policy_id = azurerm_web_application_firewall_policy.main.id

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
  }

  # WAF configuration removed - using WAF policy instead

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

  # Private pools for both clusters (NGINX ingress internal IPs)
  backend_address_pool {
    name         = "public-backend-pool"
    ip_addresses = [local.cluster_configs["public"].nginx_internal_ip]
  }

  # HTTP settings for public cluster
  backend_http_settings {
    name                  = "app1-frontend-http-settings"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
    probe_name            = "public-health-probe"
    host_name             = "app1.yourdomain.com"

    connection_draining {
      enabled           = true
      drain_timeout_sec = 300
    }
  }

  backend_http_settings {
    name                  = "app1-api-http-settings"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
    probe_name            = "public-health-probe"
    host_name             = "app1.api.yourdomain.com"

    connection_draining {
      enabled           = true
      drain_timeout_sec = 300
    }
  }

  # Health probes for both clusters
  probe {
    name                                      = "public-health-probe"
    protocol                                  = "Http"
    path                                      = "/"
    port                                      = 80
    interval                                  = 30
    timeout                                   = 20
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
    match {
      status_code = ["200"]
    }
  }

  # HTTP listeners
  http_listener {
    name                           = "appGwHttpListener"
    frontend_ip_configuration_name = "appGwPublicFrontendIp"
    frontend_port_name             = "port_80"
    protocol                       = "Http"
  }

  # HTTPS listeners with host-based routing
  http_listener {
    name                           = "public-app-listener"
    frontend_ip_configuration_name = "appGwPublicFrontendIp"
    frontend_port_name             = "port_443"
    protocol                       = "Https"
    ssl_certificate_name           = "wildcard-ssl-cert"
    host_name                      = "app1.yourdomain.com"
    firewall_policy_id             = azurerm_web_application_firewall_policy.app1.id
  }

  http_listener {
    name                           = "backend-api-listener"
    frontend_ip_configuration_name = "appGwPublicFrontendIp"
    frontend_port_name             = "port_443"
    protocol                       = "Https"
    ssl_certificate_name           = "wildcard-ssl-cert"
    host_name                      = "app1.api.yourdomain.com"
    firewall_policy_id             = azurerm_web_application_firewall_policy.app2.id
  }

  # Wildcard SSL Certificate for both domains
  ssl_certificate {
    name     = "wildcard-ssl-cert"
    data     = pkcs12_from_pem.wildcard.result
    password = random_password.generated["ssl_cert"].result
  }

  # Redirect HTTP to HTTPS (generic redirect)
  redirect_configuration {
    name                 = "http-to-https-redirect"
    redirect_type        = "Permanent"
    target_listener_name = "public-app-listener" # Default to public app
    include_path         = true
    include_query_string = true
  }

  # Routing rules
  request_routing_rule {
    name                        = "http-redirect-rule"
    rule_type                   = "Basic"
    http_listener_name          = "appGwHttpListener"
    redirect_configuration_name = "http-to-https-redirect"
    priority                    = 100
  }

  request_routing_rule {
    name                       = "public-app-routing"
    rule_type                  = "Basic"
    http_listener_name         = "public-app-listener"
    backend_address_pool_name  = "public-backend-pool"
    backend_http_settings_name = "app1-frontend-http-settings"
    priority                   = 200
  }

  request_routing_rule {
    name                       = "backend-api-routing"
    rule_type                  = "Basic"
    http_listener_name         = "backend-api-listener"
    backend_address_pool_name  = "public-backend-pool"
    backend_http_settings_name = "app1-api-http-settings"
    priority                   = 300
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
}
