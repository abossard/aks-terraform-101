########################################
# Application Baseline (per-app assets)
########################################

locals {
  app_identity_name_map = {
    for a, v in local.app_map : a => "id-app-${a}-${var.environment}-${var.location_code}-001"
  }
}

# Per-app resource groups
resource "azurerm_resource_group" "app" {
  for_each = local.app_map

  name     = local.app_resource_group_names[each.key]
  location = azurerm_resource_group.main.location
  tags     = each.value.tags
}

resource "azurerm_user_assigned_identity" "app" {
  for_each            = local.app_map
  location            = azurerm_resource_group.main.location
  name                = local.app_identity_name_map[each.key]
  resource_group_name = azurerm_resource_group.app[each.key].name
  tags                = each.value.tags
  depends_on          = [azurerm_resource_group.app]
}

# Convenience locals for downstream references
locals {
  app_identities = {
    for a, id in azurerm_user_assigned_identity.app : a => {
      id           = id.id
      client_id    = id.client_id
      principal_id = id.principal_id
    }
  }
}

########################################
# Per-App Key Vaults (with Private Endpoints)
########################################

locals {
  # Enforce KV name constraints: 3-24 chars, alphanumeric and hyphens, start with letter.
  # Compose: kv-<env><project><short><suffix> and truncate safely to 24.
  app_kv_name_map = {
    for a, v in local.app_map : a => lower(
      substr(
        "akv-${var.environment}${var.project}${v.short}${random_string.unique_suffix.result}1",
        0,
        24
      )
    )
  }
}

# Role definition for secrets access
data "azurerm_role_definition" "kv_secrets_user" {
  name  = "Key Vault Secrets User"
  scope = azurerm_resource_group.main.id
}

resource "azurerm_key_vault" "app" {
  for_each = local.app_map

  name                          = local.app_kv_name_map[each.key]
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.app[each.key].name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  enable_rbac_authorization     = true
  public_network_access_enabled = false
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
  }

  tags = each.value.tags

  lifecycle {
    precondition {
      condition     = can(regex("^[a-z][a-z0-9-]{1,22}[a-z0-9]$", local.app_kv_name_map[each.key]))
      error_message = "Key Vault name must be 3-24 chars, start with a letter, end with letter/digit, only alphanumeric or hyphen."
    }
  }
  depends_on = [azurerm_resource_group.app]
}

resource "azurerm_private_endpoint" "app_kv" {
  for_each = local.app_map

  name                = "pe-kv-${each.key}-${var.environment}-${var.location_code}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.app[each.key].name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "kv-${each.key}-private-connection"
    private_connection_resource_id = azurerm_key_vault.app[each.key].id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "kv-${each.key}-dns-zone-group"
    private_dns_zone_ids = [local.private_dns_zone_id["privatelink.vaultcore.azure.net"].id]
  }

  tags       = local.app_map[each.key].tags
  depends_on = [azurerm_subnet.private_endpoints, azurerm_key_vault.app]
}

# RBAC: allow each app's managed identity to read secrets from its KV
resource "azurerm_role_assignment" "app_kv_secrets_user" {
  for_each = local.app_map

  scope              = azurerm_key_vault.app[each.key].id
  role_definition_id = data.azurerm_role_definition.kv_secrets_user.role_definition_id
  principal_id       = local.app_identities[each.key].principal_id
  principal_type     = "ServicePrincipal"
  depends_on         = [azurerm_key_vault.app]
}

# RBAC: allow application gateway managed identity to read certificates from application's KV
resource "azurerm_role_assignment" "agw_kv_certificates_user" {
  for_each = local.app_map

  scope                = azurerm_key_vault.app[each.key].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app_gateway.principal_id
  depends_on           = [azurerm_key_vault.app]
}


########################################
# Per-App K8s primitives (namespace/SA naming) and SA YAML rendering
########################################

locals {
  # K8s-safe namespace and service account names per app
  app_k8s = {
    for a, v in local.app_map : a => {
      namespace       = substr("app-${a}", 0, 63)
      service_account = substr("wi-${a}", 0, 63)
    }
  }
}

// Render one ServiceAccount per app for its owning cluster only
locals {
  app_sa_templates = {
    for a, v in local.app_k8s : a => templatefile(
      "${path.module}/k8s/serviceaccount.tmpl.yaml",
      {
        service_account_name        = v.service_account,
        workload_identity_client_id = local.app_identities[a].client_id,
        tenant_id                   = data.azurerm_client_config.current.tenant_id,
        namespace                   = v.namespace
      }
    )
  }
}

resource "local_file" "app_service_accounts" {
  for_each = local.app_sa_templates
  content  = each.value
  filename = "${path.module}/k8s/generated/${local.app_map[each.key].cluster_key}-${each.key}-serviceaccount.yaml"
}

########################################
# Per-App Demo Echo Deployment (YAML rendering)
########################################

// Render a simple echo server deployment + service + ingress per app
locals {
  app_echo_templates = {
    for a, v in local.app_map : a => templatefile(
      "${path.module}/k8s/echo-app.tmpl.yaml",
      {
        namespace          = local.app_k8s[a].namespace,
        app_name           = a,
        ingress_class_name = "nginx-internal"
      }
    )
  }
}

resource "local_file" "app_echo_manifests" {
  for_each = local.app_echo_templates
  content  = each.value
  filename = "${path.module}/k8s/generated/${local.app_map[each.key].cluster_key}-${each.key}-echo.yaml"
}

########################################
# Federated Identity per app per cluster (AKS OIDC issuer)
########################################

resource "azurerm_federated_identity_credential" "app" {
  for_each = local.app_map

  name                = "fc-${each.key}-${var.environment}-${var.project}-${each.value.cluster_key}"
  resource_group_name = azurerm_resource_group.app[each.key].name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.main[each.value.cluster_key].oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.app[each.key].id
  subject             = "system:serviceaccount:${local.app_k8s[each.key].namespace}:${local.app_k8s[each.key].service_account}"
  depends_on          = [azurerm_resource_group.app]
}

########################################
# Per-App SQL Databases and SQL SSO (secretless)
########################################

locals {
  # Safe per-app database names (<= 128 chars for SQL DB)
  app_sql_db_names = {
    for a, v in local.app_map : a => substr("sqldb-${v.short}-${var.environment}-${var.location_code}", 0, 128)
  }
}

resource "azurerm_mssql_database" "app" {
  for_each = local.app_map

  name           = local.app_sql_db_names[each.key]
  server_id      = azurerm_mssql_server.main.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  sku_name       = "S1"
  zone_redundant = false

  threat_detection_policy {
    state           = "Enabled"
    email_addresses = [local.detected_user_email]
  }

  long_term_retention_policy {
    immutable_backups_enabled = var.ltr_immutable_backups_enabled
    monthly_retention         = var.ltr_monthly_retention
    week_of_year              = var.ltr_week_of_year
    weekly_retention          = var.ltr_weekly_retention
    yearly_retention          = var.ltr_yearly_retention
  }
  short_term_retention_policy {
    backup_interval_in_hours = var.stb_backup_interval_hour
    retention_days           = var.stb_days_of_retention
  }

  tags       = merge(local.common_tags, { App = each.key })
  depends_on = [azurerm_mssql_server.main]
}

# Create AAD contained users per app DB for the app's UAMI using sqlsso provider
resource "sqlsso_mssql_server_aad_account" "app_uami_db_owner" {
  for_each = local.app_map

  sql_server_dns = azurerm_mssql_server.main.fully_qualified_domain_name
  database       = azurerm_mssql_database.app[each.key].name
  account_name   = azurerm_user_assigned_identity.app[each.key].name
  object_id      = azurerm_user_assigned_identity.app[each.key].principal_id
  role           = "owner"

  depends_on = [
    azurerm_mssql_database.app
  ]
}
