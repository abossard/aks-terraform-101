# SQL Server Azure AD Identity Management
# Creates application identities and manages SQL Server AAD access

# Create a managed identity for the application to access SQL Database
resource "azurerm_user_assigned_identity" "sql_app_identity" {
  name                = "id-sql-app-${var.environment}-${var.location_code}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

# Configure the sqlsso provider
provider "sqlsso" {}

# Get service principal data for the managed identity
data "azuread_service_principal" "sql_app_identity" {
  object_id = azurerm_user_assigned_identity.sql_app_identity.principal_id
}

# Create SQL Server AAD account for the managed identity
resource "sqlsso_mssql_server_aad_account" "sql_app_identity" {
  sql_server_dns = azurerm_mssql_server.main.fully_qualified_domain_name
  database       = azurerm_mssql_database.main.name
  account_name   = azurerm_user_assigned_identity.sql_app_identity.name
  object_id      = azurerm_user_assigned_identity.sql_app_identity.principal_id
  role           = "owner"

  depends_on = [
    azurerm_mssql_firewall_rule.client_ip
  ]
}

# Make the current Terraform user an owner of the SQL Server
resource "sqlsso_mssql_server_aad_account" "current_user_owner" {
  sql_server_dns = azurerm_mssql_server.main.fully_qualified_domain_name
  database       = azurerm_mssql_database.main.name
  account_name   = local.detected_sql_admin_login
  object_id      = local.detected_sql_admin_object_id
  role           = "owner"

  depends_on = [
    azurerm_mssql_firewall_rule.client_ip
  ]
}

# Create federated identity credentials for each cluster
resource "azurerm_federated_identity_credential" "sql_app_identity" {
  for_each = var.clusters

  name                = "fc-sql-app-${each.key}-${var.environment}-${var.project}"
  resource_group_name = azurerm_resource_group.main.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.main[each.key].oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.sql_app_identity.id
  subject             = "system:serviceaccount:${var.app_namespace}:sql-identity-sa-${each.key}"
}

# Store the application identity information in Key Vault
resource "azurerm_key_vault_secret" "sql_app_identity_client_id" {
  name         = "sql-app-identity-client-id"
  value        = azurerm_user_assigned_identity.sql_app_identity.client_id
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
}

# Create an updated database connection string for the application identity
resource "azurerm_key_vault_secret" "database_connection_app_identity" {
  name         = "database-connection-app-identity"
  value        = "Server=${azurerm_mssql_server.main.fully_qualified_domain_name};Database=${azurerm_mssql_database.main.name};Authentication=Active Directory Managed Identity;User Id=${azurerm_user_assigned_identity.sql_app_identity.client_id};"
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
}
