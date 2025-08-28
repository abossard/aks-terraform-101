
# SQL Server
resource "azurerm_mssql_server" "main" {
  name                         = local.sql_server_name
  resource_group_name          = azurerm_resource_group.sql_shared.name
  location                     = azurerm_resource_group.sql_shared.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = random_password.generated["sql_admin"].result

  # Public endpoint toggle (bootstrap = true, hardened = false)
  public_network_access_enabled = var.sql_public_network_enabled

  # Azure AD authentication with auto-detected admin
  azuread_administrator {
    login_username = local.detected_sql_admin_login
    object_id      = local.detected_sql_admin_object_id
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags

  lifecycle {
    precondition {
      condition     = var.sql_public_network_enabled || var.enable_sql_private_endpoint
      error_message = "Cannot disable public network access unless a Private Endpoint is enabled (enable_sql_private_endpoint = true)."
    }
  }
}

# Note: Per-application databases are defined in app-baseline.tf

# Private Endpoint for SQL Server (optional via enable_sql_private_endpoint)
resource "azurerm_private_endpoint" "sql" {
  count               = var.enable_sql_private_endpoint ? 1 : 0
  name                = local.sql_pe_name
  location            = azurerm_resource_group.sql_shared.location
  resource_group_name = azurerm_resource_group.sql_shared.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "sql-private-connection"
    private_connection_resource_id = azurerm_mssql_server.main.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "sql-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.main["sql_database"].id]
  }

  tags = local.common_tags
}