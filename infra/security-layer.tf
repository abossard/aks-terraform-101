# Security Layer
# Key Vault, Private Endpoints (Firewall removed)

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