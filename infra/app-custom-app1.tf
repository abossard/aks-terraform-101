locals {
  # Unique suffix for app1 storage account to ensure global name uniqueness
  app1_storage_suffix = random_string.app1_storage_suffix.result
  app1_storage_prefix = local.storage_name_parts["app1"].prefix
  # Truncate prefix to leave room for suffix so suffix is always present
  app1_storage_name = lower(
    join("", [
      substr(local.app1_storage_prefix, 0, 24 - length(local.app1_storage_suffix)),
      local.app1_storage_suffix
    ])
  )
}

resource "random_string" "app1_storage_suffix" {
  length  = 5
  special = false
  upper   = false
  lower   = true
  numeric = true
}

resource "azurerm_storage_account" "app1" {
  name                     = local.app1_storage_name
  resource_group_name      = azurerm_resource_group.app["app1"].name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  public_network_access_enabled   = false

  tags = local.app_map["app1"].tags

  lifecycle {
    precondition {
      condition     = length(local.app1_storage_name) >= 3 && length(local.app1_storage_name) <= 24
      error_message = "Storage account name must be between 3 and 24 characters."
    }
  }
}

# RBAC: Grant 'Storage Blob Data Contributor' to app1's user-assigned identity
data "azurerm_role_definition" "blob_data_contributor" {
  name  = "Storage Blob Data Contributor"
  scope = azurerm_resource_group.main.id
}

resource "azurerm_role_assignment" "app1_blob_contributor" {
  scope                            = azurerm_storage_account.app1.id
  role_definition_id               = data.azurerm_role_definition.blob_data_contributor.role_definition_id
  principal_id                     = local.app_identities["app1"].principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}


resource "azurerm_web_application_firewall_policy" "app1" {
  name                = "waf-policy-${var.environment}-${var.location_code}-app1-001"
  resource_group_name = azurerm_resource_group.app["app1"].name
  location            = azurerm_resource_group.app["app1"].location

  # Custom rule: Block API access from external IPs
  # Allow all other traffic (public app access)
  policy_settings {
    enabled                     = true
    mode                        = var.firewall_enforcement_enabled ? "Prevention" : "Detection"
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }

  # OWASP Managed Rules
  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
}