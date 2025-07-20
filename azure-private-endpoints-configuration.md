# Azure Private Endpoints Configuration - Terraform Implementation

## Overview
Private endpoints provide secure, private connectivity to Azure services by creating a network interface within your VNet that uses a private IP address, eliminating public internet exposure.

## Required Components

### 1. Private DNS Zones

```hcl
# Private DNS Zone for Key Vault
resource "azurerm_private_dns_zone" "key_vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.main.name
}

# Private DNS Zone for Storage Account - Blob
resource "azurerm_private_dns_zone" "storage_blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.main.name
}

# Private DNS Zone for Storage Account - File
resource "azurerm_private_dns_zone" "storage_file" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.main.name
}

# Private DNS Zone for SQL Database
resource "azurerm_private_dns_zone" "sql_database" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.main.name
}
```

### 2. VNet Links for DNS Zones

```hcl
# Link Key Vault DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  name                  = "kv-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
}

# Link Storage Blob DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "storage_blob" {
  name                  = "storage-blob-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.storage_blob.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
}

# Link Storage File DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "storage_file" {
  name                  = "storage-file-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.storage_file.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
}

# Link SQL DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "sql_database" {
  name                  = "sql-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.sql_database.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
}
```

### 3. Azure Key Vault with Private Endpoint

```hcl
# Azure Key Vault
resource "azurerm_key_vault" "main" {
  name                = "kv-${var.environment}-${var.project}-${var.location_code}-${random_string.suffix.result}"
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
}

# Private Endpoint for Key Vault
resource "azurerm_private_endpoint" "key_vault" {
  name                = "pe-kv-${var.environment}-${var.project}-${var.location_code}-${random_string.suffix.result}"
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

  depends_on = [azurerm_private_dns_zone_virtual_network_link.key_vault]
}
```

### 4. Azure Storage Account with Private Endpoints

```hcl
# Storage Account
resource "azurerm_storage_account" "main" {
  name                     = "st${var.environment}${var.project}${var.location_code}${random_string.suffix.result}"
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
    versioning_enabled = true
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }
}

# Private Endpoint for Storage Account - Blob
resource "azurerm_private_endpoint" "storage_blob" {
  name                = "pe-st-blob-${var.environment}-${var.project}-${var.location_code}-${random_string.suffix.result}"
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

  depends_on = [azurerm_private_dns_zone_virtual_network_link.storage_blob]
}

# Private Endpoint for Storage Account - File
resource "azurerm_private_endpoint" "storage_file" {
  name                = "pe-st-file-${var.environment}-${var.project}-${var.location_code}-${random_string.suffix.result}"
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

  depends_on = [azurerm_private_dns_zone_virtual_network_link.storage_file]
}
```

### 5. Azure SQL Server with Private Endpoint

```hcl
# SQL Server
resource "azurerm_mssql_server" "main" {
  name                         = "sql-${var.environment}-${var.project}-${var.location_code}-${random_string.suffix.result}"
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
}

# SQL Database
resource "azurerm_mssql_database" "main" {
  name           = "sqldb-${var.environment}-${var.project}-${var.location_code}"
  server_id      = azurerm_mssql_server.main.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  sku_name       = "S1"  # Basic tier for testing
  zone_redundant = false

  # Threat detection
  threat_detection_policy {
    state           = "Enabled"
    email_addresses = [var.security_email]
  }
}

# Private Endpoint for SQL Server
resource "azurerm_private_endpoint" "sql_server" {
  name                = "pe-sql-${var.environment}-${var.project}-${var.location_code}-${random_string.suffix.result}"
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

  depends_on = [azurerm_private_dns_zone_virtual_network_link.sql_database]
}
```

### 6. Dedicated Subnet for Private Endpoints

```hcl
# Subnet for Private Endpoints
resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-pe-${var.environment}-${var.project}-${var.location_code}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vnet_address_space, 8, 3)]

  # Disable private endpoint network policies
  private_endpoint_network_policies_enabled = false
}
```

## DNS Zone Names Reference

| Service | Subresource | DNS Zone Name |
|---------|-------------|---------------|
| Key Vault | vault | `privatelink.vaultcore.azure.net` |
| Storage - Blob | blob | `privatelink.blob.core.windows.net` |
| Storage - File | file | `privatelink.file.core.windows.net` |
| Storage - Queue | queue | `privatelink.queue.core.windows.net` |
| Storage - Table | table | `privatelink.table.core.windows.net` |
| Storage - DFS | dfs | `privatelink.dfs.core.windows.net` |
| SQL Database | sqlServer | `privatelink.database.windows.net` |

## Required Variables

```hcl
variable "sql_admin_username" {
  description = "SQL Server administrator username"
  type        = string
  sensitive   = true
}

variable "sql_admin_password" {
  description = "SQL Server administrator password"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.sql_admin_password) >= 8
    error_message = "SQL admin password must be at least 8 characters long."
  }
}

variable "sql_azuread_admin_login" {
  description = "Azure AD admin login for SQL Server"
  type        = string
}

variable "sql_azuread_admin_object_id" {
  description = "Azure AD admin object ID for SQL Server"
  type        = string
}

variable "security_email" {
  description = "Email address for security notifications"
  type        = string
}
```

## Network Security Considerations

### 1. Network Security Group Rules
```hcl
# NSG rule to allow private endpoint traffic
resource "azurerm_network_security_rule" "allow_private_endpoints" {
  name                        = "AllowPrivateEndpoints"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["443", "1433"]
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = azurerm_subnet.private_endpoints.address_prefixes[0]
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.private_endpoints.name
}
```

### 2. Route Table Configuration
```hcl
# Route table for private endpoints subnet
resource "azurerm_route_table" "private_endpoints" {
  name                = "rt-pe-${var.environment}-${var.project}-${var.location_code}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Keep traffic local to VNet
  route {
    name           = "local-traffic"
    address_prefix = var.vnet_address_space
    next_hop_type  = "VnetLocal"
  }
}

# Associate route table with private endpoints subnet
resource "azurerm_subnet_route_table_association" "private_endpoints" {
  subnet_id      = azurerm_subnet.private_endpoints.id
  route_table_id = azurerm_route_table.private_endpoints.id
}
```

## Configuration Best Practices

### 1. Security
- **Disable Public Access**: Always set `public_network_access_enabled = false`
- **Network ACLs**: Configure `default_action = "Deny"` in network rules
- **RBAC**: Use Azure RBAC for fine-grained access control
- **Monitoring**: Enable diagnostic settings for all services

### 2. DNS Resolution
- **Private DNS Zones**: Create separate zones for each service type
- **VNet Links**: Link all DNS zones to the VNet
- **A Records**: Automatically created by private endpoint
- **Custom DNS**: If using custom DNS servers, configure forwarding

### 3. High Availability
- **Zone Redundancy**: Enable where supported
- **Backup**: Configure appropriate backup policies
- **Disaster Recovery**: Plan for cross-region scenarios

### 4. Monitoring and Diagnostics
```hcl
# Diagnostic settings for Key Vault
resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  name                       = "kv-diagnostics"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"
  }
}
```

## Validation Steps

1. **Connection Approval**: Verify private endpoints show "Approved" status
2. **DNS Resolution**: Test that FQDNs resolve to private IPs
3. **Network Connectivity**: Verify services are accessible from AKS pods
4. **Public Access**: Confirm public endpoints are blocked
5. **Logging**: Check that audit logs are flowing to Log Analytics