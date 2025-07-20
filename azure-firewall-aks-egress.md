# Azure Firewall for AKS Egress Control - Terraform Configuration

## Overview
Azure Firewall provides egress traffic control for AKS clusters with FQDN-based filtering, network rules, and application rules. This configuration ensures all outbound traffic is routed through the firewall for security and compliance.

## Required Components

### 1. Azure Firewall Infrastructure

```hcl
# Public IP for Azure Firewall
resource "azurerm_public_ip" "firewall_pip" {
  name                = "fw-pip-${var.environment}-${var.project}-${var.location_code}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}

# Azure Firewall
resource "azurerm_firewall" "main" {
  name                = "fw-${var.environment}-${var.project}-${var.location_code}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"  # or "Premium" for TLS inspection
  firewall_policy_id  = azurerm_firewall_policy.main.id
  dns_proxy_enabled   = true

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall_pip.id
  }
}
```

### 2. Firewall Policy and Rules

```hcl
# Firewall Policy
resource "azurerm_firewall_policy" "main" {
  name                = "fwpol-${var.environment}-${var.project}-${var.location_code}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard"  # or "Premium"
  
  dns {
    proxy_enabled = true
  }
  
  threat_intelligence_mode = "Alert"
}

# Rule Collection Group
resource "azurerm_firewall_policy_rule_collection_group" "aks_egress" {
  name               = "aks-egress-rules"
  firewall_policy_id = azurerm_firewall_policy.main.id
  priority           = 100

  # Application Rules for AKS
  application_rule_collection {
    name     = "aks-fqdn-rules"
    priority = 100
    action   = "Allow"

    rule {
      name = "aks-core-dependencies"
      protocols {
        type = "Https"
        port = 443
      }
      protocols {
        type = "Http"
        port = 80
      }
      source_addresses = ["10.240.0.0/16"]  # AKS subnet CIDR
      destination_fqdns = [
        # Core AKS dependencies
        "*.hcp.${var.location}.azmk8s.io",
        "mcr.microsoft.com",
        "*.data.mcr.microsoft.com",
        "management.azure.com",
        "login.microsoftonline.com",
        "packages.microsoft.com",
        "acs-mirror.azureedge.net",
        "packages.aks.azure.com",  # New FQDN for 2025
        
        # Ubuntu updates
        "security.ubuntu.com",
        "azure.archive.ubuntu.com",
        "changelogs.ubuntu.com",
        
        # Docker Hub (if needed)
        "*.docker.io",
        "*.docker.com",
        "registry-1.docker.io",
        "auth.docker.io",
        "production.cloudflare.docker.com",
        
        # GitHub Container Registry (if needed)
        "ghcr.io",
        "pkg-containers.githubusercontent.com"
      ]
    }

    rule {
      name = "azure-monitor"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses = ["10.240.0.0/16"]
      destination_fqdns = [
        "dc.services.visualstudio.com",
        "*.ods.opinsights.azure.com",
        "*.oms.opinsights.azure.com",
        "*.monitoring.azure.com"
      ]
    }
  }

  # Network Rules for AKS
  network_rule_collection {
    name     = "aks-network-rules"
    priority = 200
    action   = "Allow"

    rule {
      name                  = "aks-tcp-ports"
      protocols             = ["TCP"]
      source_addresses      = ["10.240.0.0/16"]
      destination_addresses = ["AzureCloud.${var.location}"]
      destination_ports     = ["9000", "443"]
    }

    rule {
      name                  = "aks-udp-ports"
      protocols             = ["UDP"]
      source_addresses      = ["10.240.0.0/16"]
      destination_addresses = ["AzureCloud.${var.location}"]
      destination_ports     = ["1194", "123"]
    }

    rule {
      name                  = "ntp-time-sync"
      protocols             = ["UDP"]
      source_addresses      = ["10.240.0.0/16"]
      destination_addresses = ["*"]
      destination_ports     = ["123"]
    }
  }
}
```

### 3. User Defined Routes (UDR)

```hcl
# Route Table for AKS Subnet
resource "azurerm_route_table" "aks_routes" {
  name                = "rt-aks-${var.environment}-${var.project}-${var.location_code}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  route {
    name                   = "default-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.main.ip_configuration[0].private_ip_address
  }

  route {
    name           = "internet-via-firewall"
    address_prefix = "Internet"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.main.ip_configuration[0].private_ip_address
  }
}

# Associate Route Table with AKS Subnet
resource "azurerm_subnet_route_table_association" "aks_routes" {
  subnet_id      = azurerm_subnet.aks.id
  route_table_id = azurerm_route_table.aks_routes.id
}
```

### 4. AKS Cluster with Firewall Integration

```hcl
resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${var.environment}-${var.project}-${var.location_code}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "aks-${var.environment}-${var.project}-${var.location_code}"
  kubernetes_version  = var.kubernetes_version

  # Use UserDefinedRouting for egress through firewall
  default_node_pool {
    name           = "default"
    node_count     = var.node_count
    vm_size        = var.node_vm_size
    vnet_subnet_id = azurerm_subnet.aks.id
    zones          = ["1", "2", "3"]
    
    enable_auto_scaling = true
    min_count          = var.min_node_count
    max_count          = var.max_node_count
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_dataplane   = "cilium"
    pod_cidr           = var.pod_cidr
    service_cidr       = var.service_cidr
    dns_service_ip     = var.dns_service_ip
    outbound_type      = "userDefinedRouting"  # Route through firewall
  }

  identity {
    type = "SystemAssigned"
  }

  depends_on = [
    azurerm_subnet_route_table_association.aks_routes
  ]
}
```

## Required FQDN Rules (2025 Updated)

### Core AKS Dependencies
- `*.hcp.<region>.azmk8s.io:443` - Control plane communication
- `mcr.microsoft.com:443` - Microsoft Container Registry
- `*.data.mcr.microsoft.com:443` - MCR data endpoints
- `management.azure.com:443` - Azure Resource Manager
- `login.microsoftonline.com:443` - Azure AD authentication
- `packages.microsoft.com:443` - Microsoft packages
- `packages.aks.azure.com:443` - **NEW 2025 requirement** (replaces acs-mirror.azureedge.net)

### Network Rules
- **TCP 9000** - Secure tunnel communication with control plane
- **UDP 1194** - OpenVPN tunnel communication
- **UDP 123** - NTP time synchronization
- **TCP 443** - HTTPS traffic to Azure services

## Production Recommendations

### Firewall Sizing
```hcl
# For production workloads, use Premium SKU and multiple IPs
resource "azurerm_public_ip" "firewall_pip_additional" {
  count               = 19  # Total 20 IPs to avoid SNAT exhaustion
  name                = "fw-pip-${count.index + 2}-${var.environment}-${var.project}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
}
```

### Monitoring Integration
```hcl
# Diagnostic Settings for Azure Firewall
resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                       = "firewall-diagnostics"
  target_resource_id         = azurerm_firewall.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "AzureFirewallApplicationRule"
  }

  enabled_log {
    category = "AzureFirewallNetworkRule"
  }

  metric {
    category = "AllMetrics"
  }
}
```

## Key Configuration Notes

1. **DNS Proxy**: Enable DNS proxy on firewall for enhanced security
2. **Multiple Frontend IPs**: Use minimum 20 frontend IPs for production to avoid SNAT port exhaustion
3. **Outbound Type**: Set AKS `outbound_type = "userDefinedRouting"` to force traffic through firewall
4. **FQDN Updates**: Add `packages.aks.azure.com:443` by August 2025 for new VHD images
5. **Zones**: Deploy firewall across availability zones for high availability