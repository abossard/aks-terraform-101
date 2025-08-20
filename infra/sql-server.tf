
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