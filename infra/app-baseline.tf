########################################
# Application Baseline (per-app assets)
########################################

locals {
  app_identity_name_map = {
    for a, v in local.app_map : a => "id-app-${a}-${var.environment}-${var.location_code}-001"
  }
}

resource "azurerm_user_assigned_identity" "app" {
  for_each            = local.app_map
  location            = azurerm_resource_group.main.location
  name                = local.app_identity_name_map[each.key]
  resource_group_name = azurerm_resource_group.main.name
  tags                = each.value.tags
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
        "kv-${var.environment}${var.project}${v.short}${random_string.unique_suffix.result}",
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
  resource_group_name           = azurerm_resource_group.main.name
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
}

resource "azurerm_private_endpoint" "app_kv" {
  for_each = local.app_map

  name                = "pe-kv-${each.key}-${var.environment}-${var.location_code}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "kv-${each.key}-private-connection"
    private_connection_resource_id = azurerm_key_vault.app[each.key].id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "kv-${each.key}-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.main["key_vault"].id]
  }

  tags = local.app_map[each.key].tags
}

# RBAC: allow each app's managed identity to read secrets from its KV
resource "azurerm_role_assignment" "app_kv_secrets_user" {
  for_each = local.app_map

  scope              = azurerm_key_vault.app[each.key].id
  role_definition_id = data.azurerm_role_definition.kv_secrets_user.role_definition_id
  principal_id       = local.app_identities[each.key].principal_id
  principal_type     = "ServicePrincipal"
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

# Render ServiceAccount YAML per app per cluster (so users can apply to any cluster easily)
locals {
  app_sa_manifests = {
    for combo in flatten([
      for ck, cv in var.clusters : [
        for ak, av in local.app_k8s : {
          key       = "${ck}|${ak}"
          cluster   = ck
          app       = ak
          namespace = av.namespace
          sa_name   = av.service_account
        }
      ]
      ]) : combo.key => templatefile(
      "${path.module}/k8s/serviceaccount.tmpl.yaml",
      {
        service_account_name        = combo.sa_name,
        workload_identity_client_id = local.app_identities[combo.app].client_id,
        tenant_id                   = data.azurerm_client_config.current.tenant_id,
        namespace                   = combo.namespace
      }
    )
  }
}

resource "local_file" "app_service_accounts" {
  for_each = local.app_sa_manifests

  content  = each.value
  filename = "${path.module}/k8s/generated/${replace(each.key, "|", "-")}-serviceaccount.yaml"
}

########################################
# Federated Identity per app per cluster (AKS OIDC issuer)
########################################

locals {
  app_fic_keys = flatten([
    for ck, cv in var.clusters : [
      for ak, av in local.app_k8s : "${ck}|${ak}"
    ]
  ])
}

resource "azurerm_federated_identity_credential" "app" {
  for_each = toset(local.app_fic_keys)

  name                = "fc-${split("|", each.key)[1]}-${var.environment}-${var.project}-${split("|", each.key)[0]}"
  resource_group_name = azurerm_resource_group.main.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.main[split("|", each.key)[0]].oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.app[split("|", each.key)[1]].id
  subject             = "system:serviceaccount:${local.app_k8s[split("|", each.key)[1]].namespace}:${local.app_k8s[split("|", each.key)[1]].service_account}"
}