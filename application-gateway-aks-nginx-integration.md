# Azure Application Gateway + AKS + NGINX Ingress Integration

## Architecture Overview
This configuration creates a secure ingress path: Internet → Application Gateway (Public IP + WAF) → NGINX Ingress Controller (Internal Load Balancer) → AKS Pods.

## Components Required

### 1. Application Gateway with WAF

```hcl
# Public IP for Application Gateway
resource "azurerm_public_ip" "app_gateway_pip" {
  name                = "pip-agw-${var.environment}-${var.project}-${var.location_code}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}

# Application Gateway
resource "azurerm_application_gateway" "main" {
  name                = "agw-${var.environment}-${var.project}-${var.location_code}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }

  waf_configuration {
    enabled                  = true
    firewall_mode           = "Prevention"
    rule_set_type           = "OWASP"
    rule_set_version        = "3.2"
    file_upload_limit_mb    = 100
    request_body_check      = true
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
    public_ip_address_id = azurerm_public_ip.app_gateway_pip.id
  }

  # Backend pool pointing to NGINX Ingress internal IP
  backend_address_pool {
    name         = "nginx-backend-pool"
    ip_addresses = [var.nginx_internal_ip]  # Calculated static internal IP
  }

  backend_http_settings {
    name                  = "nginx-backend-http-settings"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
    probe_name           = "nginx-health-probe"
    
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
    probe_name           = "nginx-health-probe-https"
    
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
    host                = var.nginx_internal_ip
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
    host                = var.nginx_internal_ip
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

  # SSL Certificate (if using HTTPS)
  ssl_certificate {
    name     = "app-gateway-ssl-cert"
    data     = filebase64("path/to/certificate.pfx")
    password = var.ssl_cert_password
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
}
```

### 2. NGINX Ingress Controller with Internal Load Balancer

```yaml
# nginx-ingress-internal.yaml (deployed via Helm or kubectl)
apiVersion: v1
kind: Service
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
    service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "aks-subnet"
spec:
  type: LoadBalancer
  loadBalancerIP: 10.240.0.100  # Static internal IP (calculated)
  ports:
  - name: http
    port: 80
    protocol: TCP
    targetPort: 80
  - name: https
    port: 443
    protocol: TCP
    targetPort: 443
  selector:
    app.kubernetes.io/component: controller
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
```

### 3. Helm Installation for NGINX Ingress

```hcl
# Deploy NGINX Ingress via Helm (requires helm provider)
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.8.0"

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.service.loadBalancerIP"
    value = var.nginx_internal_ip
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-internal"
    value = "true"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-internal-subnet"
    value = "aks-subnet"
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

  depends_on = [azurerm_kubernetes_cluster.main]
}
```

### 4. Variables for IP Configuration

```hcl
# Variables for calculated IPs
variable "nginx_internal_ip" {
  description = "Static internal IP for NGINX ingress controller"
  type        = string
  default     = "10.240.0.100"  # Must be within AKS subnet range
}

# Calculate NGINX internal IP from subnet
locals {
  nginx_internal_ip = cidrhost(azurerm_subnet.aks.address_prefixes[0], 100)
}
```

### 5. Network Security Group Rules

```hcl
# NSG rule to allow Application Gateway to reach NGINX
resource "azurerm_network_security_rule" "allow_app_gateway_to_nginx" {
  name                        = "AllowAppGatewayToNginx"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefix       = azurerm_subnet.app_gateway.address_prefixes[0]
  destination_address_prefix  = azurerm_subnet.aks.address_prefixes[0]
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.aks.name
}

# NSG rule for Application Gateway management traffic
resource "azurerm_network_security_rule" "allow_gateway_manager" {
  name                        = "AllowGatewayManager"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "65200-65535"  # For WAF_v2 SKU
  source_address_prefix       = "GatewayManager"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.app_gateway.name
}
```

## Configuration Best Practices

### 1. Health Probe Configuration
- Configure health probes to check `/healthz` endpoint on NGINX
- Use appropriate timeouts and thresholds
- Monitor both HTTP and HTTPS endpoints

### 2. SSL/TLS Configuration
- Terminate SSL at Application Gateway
- Use Azure Key Vault for certificate management
- Configure proper cipher suites and TLS versions

### 3. WAF Configuration
- Enable OWASP Core Rule Set 3.2
- Set to Prevention mode for production
- Configure custom rules as needed
- Monitor WAF logs for blocked requests

### 4. Scaling Configuration
- Enable autoscaling on Application Gateway
- Configure appropriate min/max capacity
- Monitor performance metrics

### 5. Monitoring and Logging
```hcl
# Diagnostic settings for Application Gateway
resource "azurerm_monitor_diagnostic_setting" "app_gateway" {
  name                       = "app-gateway-diagnostics"
  target_resource_id         = azurerm_application_gateway.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  enabled_log {
    category = "ApplicationGatewayPerformanceLog"
  }

  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }

  metric {
    category = "AllMetrics"
  }
}
```

## Traffic Flow Summary

1. **Internet Traffic** → Application Gateway Public IP
2. **WAF Processing** → OWASP rule evaluation and filtering
3. **Load Balancing** → Route to NGINX Ingress internal IP
4. **Internal Routing** → NGINX Ingress Controller processes requests
5. **Service Discovery** → Route to appropriate Kubernetes services
6. **Pod Delivery** → Final delivery to application pods

## Key Benefits

- **Single Public Entry Point**: Only Application Gateway has public IP
- **WAF Protection**: OWASP Core Rule Set 3.2 protection
- **Internal Security**: AKS cluster has no direct internet exposure
- **High Availability**: Multi-zone deployment with autoscaling
- **SSL Termination**: Centralized certificate management
- **Health Monitoring**: Proactive health checking and failover