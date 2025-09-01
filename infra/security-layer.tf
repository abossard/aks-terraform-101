# Security Layer
# Key Vault, Private Endpoints, Optional Azure Firewall (audit-mode default)

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


// Azure Firewall and related egress controls removed as part of simplification.
// Retained: Key Vault, Storage, SQL Private Endpoints, Private DNS zones.

# -----------------------------------------------------------------------------
# Optional Azure Firewall (egress governance & centralized policy)
# -----------------------------------------------------------------------------
resource "azurerm_public_ip" "firewall" {
  count               = var.enable_firewall ? 1 : 0
  name                = local.firewall_pip_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_firewall_policy" "main" {
  count               = var.enable_firewall ? 1 : 0
  name                = local.firewall_policy_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Premium"
  tags                = local.common_tags

  # Audit posture by default: threat intel alerts only; no deny unless enforcement flag enabled triggers stricter rule sets in future.
  threat_intelligence_mode = "Alert"

  dns {
    proxy_enabled = true
  }
}

resource "azurerm_firewall_policy_rule_collection_group" "main" {
  count              = var.enable_firewall ? 1 : 0
  name               = local.firewall_rcg_name
  firewall_policy_id = azurerm_firewall_policy.main[0].id
  priority           = 100

  # Application FQDN rules for AKS core dependencies (audit / allow list)
  application_rule_collection {
    name     = "aks-fqdn-core"
    priority = 100
    action   = "Allow"

    rule {
      name             = "aks-core-dependencies"
      source_addresses = [for k, v in var.clusters : azurerm_subnet.clusters[k].address_prefixes[0]]
      destination_fqdns = [
        "*.hcp.${var.location}.azmk8s.io",
        "mcr.microsoft.com",
        "*.data.mcr.microsoft.com",
        "management.azure.com",
        "login.microsoftonline.com",
        "packages.microsoft.com",
        "packages.aks.azure.com",
        "security.ubuntu.com",
        "azure.archive.ubuntu.com",
        "changelogs.ubuntu.com",
        "*.docker.io",
        "*.docker.com",
        "registry-1.docker.io",
        "auth.docker.io",
        "production.cloudflare.docker.com",
        "ghcr.io",
        "pkg-containers.githubusercontent.com",
        "dc.services.visualstudio.com",
        "*.ods.opinsights.azure.com",
        "*.oms.opinsights.azure.com",
        "*.monitoring.azure.com"
      ]
      protocols {
        type = "Https"
        port = 443
      }
      protocols {
        type = "Http"
        port = 80
      }
    }
  }

  # Network rules (ports required for AKS control plane tunnels, NTP, web)
  network_rule_collection {
    name     = "aks-network-rules"
    priority = 200
    action   = "Allow"

    # TCP web outbound
    rule {
      name                  = "web-tcp"
      source_addresses      = [for k, v in var.clusters : azurerm_subnet.clusters[k].address_prefixes[0]]
      destination_addresses = ["*"]
      destination_ports     = ["80", "443"]
      protocols             = ["TCP"]
    }

    # AKS control plane secure tunnel TCP 9000
    rule {
      name                  = "aks-tcp-9000"
      source_addresses      = [for k, v in var.clusters : azurerm_subnet.clusters[k].address_prefixes[0]]
      destination_addresses = ["*"]
      destination_ports     = ["9000"]
      protocols             = ["TCP"]
    }

    # AKS / OpenVPN UDP 1194
    rule {
      name                  = "aks-udp-1194"
      source_addresses      = [for k, v in var.clusters : azurerm_subnet.clusters[k].address_prefixes[0]]
      destination_addresses = ["*"]
      destination_ports     = ["1194"]
      protocols             = ["UDP"]
    }

    # NTP time sync UDP 123
    rule {
      name                  = "ntp-udp-123"
      source_addresses      = [for k, v in var.clusters : azurerm_subnet.clusters[k].address_prefixes[0]]
      destination_addresses = ["*"]
      destination_ports     = ["123"]
      protocols             = ["UDP"]
    }
  }

  # DNS rule included only when enforcement (otherwise broad allow above suffices)
  dynamic "network_rule_collection" {
    for_each = var.firewall_enforcement_enabled ? [1] : []
    content {
      name     = "aks-dns"
      priority = 210
      action   = "Allow"
      rule {
        name                  = "dns-udp-53"
        source_addresses      = [for k, v in var.clusters : azurerm_subnet.clusters[k].address_prefixes[0]]
        destination_addresses = ["*"]
        destination_ports     = ["53"]
        protocols             = ["UDP"]
      }
    }
  }
}

resource "azurerm_firewall" "main" {
  count              = var.enable_firewall ? 1 : 0
  name               = local.firewall_name
  location           = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name           = "AZFW_VNet"
  sku_tier           = "Premium"
  firewall_policy_id = azurerm_firewall_policy.main[0].id

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall[0].id
    public_ip_address_id = azurerm_public_ip.firewall[0].id
  }

  tags = local.common_tags
}

resource "azurerm_monitor_diagnostic_setting" "firewall" {
  count                      = var.enable_firewall ? 1 : 0
  name                       = "diag-firewall"
  target_resource_id         = azurerm_firewall.main[0].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log { category = "AzureFirewallApplicationRule" }
  enabled_log { category = "AzureFirewallNetworkRule" }
  enabled_log { category = "AzureFirewallDnsProxy" }

  # metric block deprecated in some provider versions, relying on default platform metrics
}

resource "azurerm_route_table" "firewall_egress" {
  count               = var.enable_firewall && var.route_egress_through_firewall ? 1 : 0
  name                = "rt-afw-egress-${var.environment}-${var.location_code}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  # default BGP propagation setting retained
  tags                = local.common_tags

  route {
    name                   = "default-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.main[0].ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "cluster_fw" {
  for_each = (var.enable_firewall && var.route_egress_through_firewall) ? var.clusters : {}
  subnet_id      = azurerm_subnet.clusters[each.key].id
  route_table_id = azurerm_route_table.firewall_egress[0].id
}