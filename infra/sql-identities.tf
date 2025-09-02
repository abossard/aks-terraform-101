# SQL Server Azure AD Identity Management
# Creates application identities and manages SQL Server AAD access

# Create a managed identity for the application to access SQL Database
resource "azurerm_user_assigned_identity" "sql_app_identity" {
  name                = "id-sql-app-${var.environment}-${var.location_code}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# Configure the sqlsso provider
provider "sqlsso" {}

# Get service principal data for the managed identity
data "azuread_service_principal" "sql_app_identity" {
  object_id = azurerm_user_assigned_identity.sql_app_identity.principal_id
}

# Create SQL Server AAD account for the managed identity
// Removed shared DB-level AAD account; per-app DB users are created in app-baseline.tf

# Make the current Terraform user an owner of the SQL Server
// Removed shared DB owner grant for current user; optional to recreate per-app DB if desired

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
  depends_on   = [time_sleep.kv_rbac_propagation]
}

# Create an updated database connection string for the application identity
// Removed connection-string secret (Managed Identity is secretless). Use outputs/config instead.
