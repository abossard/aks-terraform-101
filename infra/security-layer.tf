# Security Layer
# Azure Firewall, Key Vault, Private Endpoints

# Private DNS Zones
resource "azurerm_private_dns_zone" "key_vault" {
  name                = local.key_vault_dns_zone
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone" "storage_blob" {
  name                = local.storage_blob_dns_zone
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone" "storage_file" {
  name                = local.storage_file_dns_zone
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone" "sql_database" {
  name                = local.sql_dns_zone
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

# VNet Links for DNS Zones
resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  name                  = "kv-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_blob" {
  name                  = "storage-blob-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.storage_blob.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_file" {
  name                  = "storage-file-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.storage_file.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_database" {
  name                  = "sql-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.sql_database.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = local.common_tags
}

# Azure Key Vault
resource "azurerm_key_vault" "main" {
  name                = local.key_vault_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Disable public network access
  public_network_access_enabled = false

  # Enable RBAC for access control
  enable_rbac_authorization = true

  # Purge protection for production
  purge_protection_enabled = true

  # Soft delete retention
  soft_delete_retention_days = 7

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
  }

  tags = local.common_tags
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
    private_dns_zone_ids = [azurerm_private_dns_zone.key_vault.id]
  }

  tags = local.common_tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.key_vault]
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

  tags = local.common_tags
}

# Private Endpoint for Storage Account - Blob
resource "azurerm_private_endpoint" "storage_blob" {
  name                = "${local.storage_pe_name}-blob"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "storage-blob-private-connection"
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "storage-blob-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage_blob.id]
  }

  tags = local.common_tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.storage_blob]
}

# Private Endpoint for Storage Account - File
resource "azurerm_private_endpoint" "storage_file" {
  name                = "${local.storage_pe_name}-file"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "storage-file-private-connection"
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "storage-file-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage_file.id]
  }

  tags = local.common_tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.storage_file]
}

# SQL Server
resource "azurerm_mssql_server" "main" {
  name                         = local.sql_server_name
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password

  # Disable public network access
  public_network_access_enabled = false

  # Azure AD authentication
  azuread_administrator {
    login_username = var.sql_azuread_admin_login
    object_id      = var.sql_azuread_admin_object_id
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

  # Threat detection
  threat_detection_policy {
    state           = "Enabled"
    email_addresses = [var.security_email]
  }

  tags = local.common_tags
}

# Private Endpoint for SQL Server
resource "azurerm_private_endpoint" "sql_server" {
  name                = local.sql_pe_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "sql-private-connection"
    private_connection_resource_id = azurerm_mssql_server.main.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "sql-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql_database.id]
  }

  tags = local.common_tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.sql_database]
}

# Azure Firewall Public IP
resource "azurerm_public_ip" "firewall" {
  name                = local.firewall_pip_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.common_tags
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

  threat_intelligence_mode = "Alert"
  tags                     = local.common_tags
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
    action   = "Allow"

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
      source_addresses = [local.aks_subnet_cidr]
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
      source_addresses = [local.aks_subnet_cidr]
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
    action   = "Allow"

    rule {
      name                  = "aks-tcp-ports"
      protocols             = ["TCP"]
      source_addresses      = [local.aks_subnet_cidr]
      destination_addresses = ["AzureCloud.${var.location}"]
      destination_ports     = ["9000", "443"]
    }

    rule {
      name                  = "aks-udp-ports"
      protocols             = ["UDP"]
      source_addresses      = [local.aks_subnet_cidr]
      destination_addresses = ["AzureCloud.${var.location}"]
      destination_ports     = ["1194", "123"]
    }

    rule {
      name                  = "ntp-time-sync"
      protocols             = ["UDP"]
      source_addresses      = [local.aks_subnet_cidr]
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
  dns_proxy_enabled   = true

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  tags = local.common_tags
}

# Route Table for AKS Subnet (force traffic through firewall)
resource "azurerm_route_table" "aks_routes" {
  name                = local.firewall_route_table_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  route {
    name                   = "default-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.main.ip_configuration[0].private_ip_address
  }

  tags = local.common_tags
}

# Associate Route Table with AKS Subnet
resource "azurerm_subnet_route_table_association" "aks_routes" {
  subnet_id      = azurerm_subnet.aks.id
  route_table_id = azurerm_route_table.aks_routes.id
}