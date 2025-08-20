# Security Layer
# Azure Firewall, Key Vault, Private Endpoints

# Private DNS Zones
resource "azurerm_private_dns_zone" "main" {
  for_each = local.private_dns_zones

  name                = each.value
  resource_group_name = azurerm_resource_group.main.name
}

# VNet Links for DNS Zones
resource "azurerm_private_dns_zone_virtual_network_link" "main" {
  for_each = local.private_dns_zones

  name                  = "${each.key}-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.main[each.key].name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
}

# Azure Key Vault
resource "azurerm_key_vault" "main" {
  name                = local.key_vault_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Enable public network access for initial deployment  
  public_network_access_enabled = true

  # Enable RBAC for access control
  enable_rbac_authorization = true

  # Purge protection for production
  purge_protection_enabled = true

  # Soft delete retention
  soft_delete_retention_days = 7

  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow"                               # Allow all for initial deployment
    ip_rules       = [chomp(data.http.myip.response_body)] # Current public IP
  }

}

# Grant current user Key Vault Administrator role for initial setup
resource "azurerm_role_assignment" "current_user_key_vault_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Wait 60 seconds for RBAC propagation before secret operations
resource "time_sleep" "kv_rbac_propagation" {
  depends_on = [azurerm_role_assignment.current_user_key_vault_admin]

  create_duration = "60s"
}

# Private Endpoint for Key Vault
resource "azurerm_private_endpoint" "key_vault" {
  name                = local.key_vault_pe_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "kv-private-connection"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "kv-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.main["key_vault"].id]
  }

  tags = local.common_tags
}

# Storage Account
resource "azurerm_storage_account" "main" {
  name                     = local.storage_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  # Disable public network access
  public_network_access_enabled = false

  # Enable hierarchical namespace for Data Lake
  is_hns_enabled = true

  # Network rules
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  blob_properties {
    versioning_enabled = false
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

}

# Private Endpoints for Storage Account
resource "azurerm_private_endpoint" "storage" {
  for_each = local.storage_endpoints

  name                = "${local.storage_pe_name}-${each.key}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "storage-${each.key}-private-connection"
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names              = [each.value.subresource]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "storage-${each.key}-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.main[each.value.dns_zone].id]
  }

}

# SQL Server
resource "azurerm_mssql_server" "main" {
  name                         = local.sql_server_name
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = random_password.generated["sql_admin"].result

  # Enable public network access for initial deployment
  public_network_access_enabled = true

  # Azure AD authentication with auto-detected admin
  azuread_administrator {
    login_username = local.detected_sql_admin_login
    object_id      = local.detected_sql_admin_object_id
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# SQL Database
resource "azurerm_mssql_database" "main" {
  name           = local.sql_database_name
  server_id      = azurerm_mssql_server.main.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  sku_name       = "S1"
  zone_redundant = false

  # Threat detection with auto-detected email
  threat_detection_policy {
    state           = "Enabled"
    email_addresses = [local.detected_user_email]
  }

  tags = local.common_tags
}

# SQL Server Firewall Rule to allow current client IP
resource "azurerm_mssql_firewall_rule" "client_ip" {
  name             = "AllowCurrentClientIP"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = chomp(data.http.myip.response_body)
  end_ip_address   = chomp(data.http.myip.response_body)
}

# Azure Firewall Public IP
resource "azurerm_public_ip" "firewall" {
  name                = local.firewall_pip_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}

# Azure Firewall Policy
resource "azurerm_firewall_policy" "main" {
  name                = local.firewall_policy_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard"

  dns {
    proxy_enabled = true
  }

  threat_intelligence_mode = var.firewall_enforcement_enabled ? "Alert" : "Off"
}

# Firewall Policy Rule Collection Group
resource "azurerm_firewall_policy_rule_collection_group" "aks_egress" {
  name               = "aks-egress-rules"
  firewall_policy_id = azurerm_firewall_policy.main.id
  priority           = 100

  # Application Rules for AKS
  application_rule_collection {
    name     = "aks-fqdn-rules"
    priority = 100
    action   = var.firewall_enforcement_enabled ? "Allow" : "Allow"

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
      source_addresses = [
        var.clusters.public.subnet_cidr,
        var.clusters.backend.subnet_cidr,
      ]
      destination_fqdns = [
        # Core AKS dependencies
        "*.hcp.${var.location_code}.azmk8s.io",
        "mcr.microsoft.com",
        "*.data.mcr.microsoft.com",
        "management.azure.com",
        "login.microsoftonline.com",
        "packages.microsoft.com",
        "acs-mirror.azureedge.net",
        "packages.aks.azure.com", # New FQDN for 2025

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
      source_addresses = [
        var.clusters.public.subnet_cidr,
        var.clusters.backend.subnet_cidr,
      ]
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
    action   = var.firewall_enforcement_enabled ? "Allow" : "Allow"

    # Ensure AKS control-plane tunnel connectivity (TCP 9000)
    rule {
      name      = "aks-tunnel-9000"
      protocols = ["TCP"]
      source_addresses = [
        var.clusters.public.subnet_cidr,
        var.clusters.backend.subnet_cidr,
      ]
      destination_fqdns = ["*.tun.${var.location_code}.azmk8s.io"]
      destination_ports = ["9000"]
    }

    rule {
      name      = "aks-tcp-ports"
      protocols = ["TCP"]
      source_addresses = [
        var.clusters.public.subnet_cidr,
        var.clusters.backend.subnet_cidr,
      ]
      destination_addresses = ["AzureCloud.${var.location}"]
      destination_ports     = ["9000", "443"]
    }

    rule {
      name      = "aks-udp-ports"
      protocols = ["UDP"]
      source_addresses = [
        var.clusters.public.subnet_cidr,
        var.clusters.backend.subnet_cidr,
      ]
      destination_addresses = ["AzureCloud.${var.location}"]
      destination_ports     = ["1194", "123"]
    }

    rule {
      name      = "ntp-time-sync"
      protocols = ["UDP"]
      source_addresses = [
        var.clusters.public.subnet_cidr,
        var.clusters.backend.subnet_cidr,
      ]
      destination_addresses = ["*"]
      destination_ports     = ["123"]
    }
  }
}

# Azure Firewall
resource "azurerm_firewall" "main" {
  name                = local.firewall_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.main.id

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

}

# Diagnostic settings: send Azure Firewall logs to Log Analytics (resource-specific tables)
resource "azurerm_monitor_diagnostic_setting" "firewall_logs" {
  name                       = "fw-logs-to-law"
  target_resource_id         = azurerm_firewall.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  # Use resource-specific tables for better performance/cost
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category = "AZFWNetworkRule"
  }
  enabled_log {
    category = "AZFWApplicationRule"
  }
  enabled_log {
    category = "AZFWDnsQuery"
  }
  enabled_log {
    category = "AZFWThreatIntel"
  }

  # Optional advanced categories (uncomment if needed and supported in your SKU/features)
  # enabled_log { category = "AZFWFlowTrace" }
  # enabled_log { category = "AZFWFatFlow" }
  # enabled_log { category = "AZFWApplicationRuleAggregation" }
  # enabled_log { category = "AZFWNetworkRuleAggregation" }
  # enabled_log { category = "AZFWIdpsSignature" }
}

# Route Table for AKS Subnet (force traffic through firewall)
resource "azurerm_route_table" "aks_routes" {
  name                = local.firewall_route_table_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Bypass Azure DNS (168.63.129.16) from the firewall so nodes can resolve using the platform resolver
  route {
    name           = "azure-dns-exception"
    address_prefix = "168.63.129.16/32"
    next_hop_type  = "Internet"
  }

  route {
    name                   = "default-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.main.ip_configuration[0].private_ip_address
  }

}

# Associate route table with all AKS cluster subnets (forces egress via firewall)
resource "azurerm_subnet_route_table_association" "aks_clusters" {
  for_each = var.route_egress_through_firewall ? azurerm_subnet.clusters : {}

  subnet_id      = azurerm_subnet.clusters[each.key].id
  route_table_id = azurerm_route_table.aks_routes.id
}

# Route table association enforces egress via Azure Firewall. Ensure required control plane and DNS
# exceptions are allowed (see rules above) so that AKS nodes remain Ready.