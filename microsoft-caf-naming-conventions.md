# Microsoft Cloud Adoption Framework (CAF) Naming Conventions

## Overview
Microsoft CAF provides standardized naming conventions for Azure resources to ensure consistency, clarity, and effective governance across cloud environments.

## Core Naming Principles

### 1. Naming Format
```
{resource-abbreviation}-{workload/project}-{environment}-{region}-{instance}
```

### 2. Key Rules
- **Permanence**: Resource names cannot be changed after creation
- **Uniqueness**: Names must be unique within their specific scope
- **Length Limits**: Each resource type has specific length constraints
- **Valid Characters**: Only certain characters are allowed per resource type
- **Delimiters**: Use hyphens (-) for readability where supported

## Resource Abbreviations (CAF Standardized)

### Compute and Web
| Resource | Abbreviation | Example |
|----------|-------------|---------|
| Azure Kubernetes Service cluster | `aks` | `aks-prod-workload-eastus-001` |
| Virtual machine | `vm` | `vm-web-prod-eastus-001` |
| Web app | `app` | `app-portal-prod-eastus-001` |
| Function app | `func` | `func-processor-prod-eastus-001` |
| Container instance | `ci` | `ci-worker-dev-eastus-001` |

### Networking
| Resource | Abbreviation | Example |
|----------|-------------|---------|
| Virtual network | `vnet` | `vnet-hub-prod-eastus-001` |
| Subnet | `snet` | `snet-aks-prod-eastus-001` |
| Network security group | `nsg` | `nsg-aks-prod-eastus-001` |
| Public IP address | `pip` | `pip-agw-prod-eastus-001` |
| Load balancer | `lb` | `lb-internal-prod-eastus-001` |
| Application gateway | `agw` | `agw-main-prod-eastus-001` |
| Route table | `rt` | `rt-spoke-prod-eastus-001` |
| Private endpoint | `pe` | `pe-kv-prod-eastus-001` |

### Security
| Resource | Abbreviation | Example |
|----------|-------------|---------|
| Key vault | `kv` | `kv-secrets-prod-eastus-001` |
| Managed identity | `id` | `id-workload-prod-eastus-001` |
| Azure Firewall | `fw` | `fw-hub-prod-eastus-001` |
| Firewall policy | `fwpol` | `fwpol-main-prod-eastus-001` |

### Storage
| Resource | Abbreviation | Example |
|----------|-------------|---------|
| Storage account | `st` | `stappdata001` (no hyphens allowed) |
| Azure Files share | `fs` | `fs-config-prod-001` |
| Data Lake Storage | `dls` | `dlsanalytics001` |

### Databases
| Resource | Abbreviation | Example |
|----------|-------------|---------|
| SQL Database server | `sql` | `sql-main-prod-eastus-001` |
| SQL Database | `sqldb` | `sqldb-orders-prod-eastus` |
| Azure Database for PostgreSQL | `psql` | `psql-app-prod-eastus-001` |
| Azure Database for MySQL | `mysql` | `mysql-web-prod-eastus-001` |

### Management and Governance
| Resource | Abbreviation | Example |
|----------|-------------|---------|
| Resource group | `rg` | `rg-workload-prod-eastus-001` |
| Log Analytics workspace | `log` | `log-monitoring-prod-eastus-001` |
| Application Insights | `appi` | `appi-portal-prod-eastus-001` |

## Naming Convention for Our AKS Infrastructure

### Base Pattern
```
{abbreviation}-{environment}-{project}-{location-code}-{instance}
```

### Environment Codes
- `dev` - Development
- `test` - Testing/Staging  
- `prod` - Production

### Location Codes
- `eus` - East US
- `wus` - West US
- `neu` - North Europe
- `weu` - West Europe

### Project Name
- Use short, descriptive project identifier (e.g., `aks101`, `webapp`, `data`)

## Complete Naming Examples for AKS Infrastructure

### Core Infrastructure
```hcl
# Resource Group
resource_group_name = "rg-prod-aks101-eus-001"

# Virtual Network
virtual_network_name = "vnet-prod-aks101-eus-001"

# Subnets
aks_subnet_name = "snet-aks-prod-eus-001"
app_gateway_subnet_name = "snet-agw-prod-eus-001"
firewall_subnet_name = "AzureFirewallSubnet"  # Fixed name required
private_endpoints_subnet_name = "snet-pe-prod-eus-001"

# Network Security Groups
aks_nsg_name = "nsg-aks-prod-eus-001"
app_gateway_nsg_name = "nsg-agw-prod-eus-001"
```

### AKS Cluster
```hcl
# AKS Cluster
aks_cluster_name = "aks-prod-aks101-eus-001"

# Managed Identity
workload_identity_name = "id-workload-prod-eus-001"

# Log Analytics
log_analytics_name = "log-aks-prod-eus-001"
```

### Application Gateway
```hcl
# Public IP
app_gateway_pip_name = "pip-agw-prod-eus-001"

# Application Gateway
app_gateway_name = "agw-main-prod-eus-001"
```

### Azure Firewall
```hcl
# Firewall Public IP
firewall_pip_name = "pip-fw-prod-eus-001"

# Azure Firewall
firewall_name = "fw-hub-prod-eus-001"

# Firewall Policy
firewall_policy_name = "fwpol-main-prod-eus-001"

# Route Table
firewall_route_table_name = "rt-fw-prod-eus-001"
```

### Private Services
```hcl
# Key Vault (15 character limit)
key_vault_name = "kv-prod-aks101-eus-001"

# Storage Account (24 characters, alphanumeric only)
storage_account_name = "stprodaks101eus001"

# SQL Server
sql_server_name = "sql-main-prod-eus-001"

# SQL Database
sql_database_name = "sqldb-app-prod-eus"

# Private Endpoints
key_vault_pe_name = "pe-kv-prod-eus-001"
storage_pe_name = "pe-st-prod-eus-001"
sql_pe_name = "pe-sql-prod-eus-001"
```

### DNS Zones
```hcl
# Private DNS Zones (fixed names)
key_vault_dns_zone = "privatelink.vaultcore.azure.net"
storage_blob_dns_zone = "privatelink.blob.core.windows.net"
storage_file_dns_zone = "privatelink.file.core.windows.net"
sql_dns_zone = "privatelink.database.windows.net"
```

## Terraform Variables for Naming

```hcl
# Core naming variables
variable "environment" {
  description = "Environment designation"
  type        = string
  default     = "prod"
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be dev, test, or prod."
  }
}

variable "project" {
  description = "Project identifier"
  type        = string
  default     = "aks101"
  validation {
    condition     = length(var.project) <= 10
    error_message = "Project name must be 10 characters or less."
  }
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

variable "location_code" {
  description = "Short location identifier"
  type        = string
  default     = "eus"
}

# Random suffix for uniqueness
resource "random_string" "suffix" {
  length  = 3
  special = false
  upper   = false
  numeric = true
}

# Local values for consistent naming
locals {
  # Common naming components
  base_name = "${var.environment}-${var.project}-${var.location_code}"
  
  # Resource group
  resource_group_name = "rg-${local.base_name}-001"
  
  # Networking
  vnet_name = "vnet-${local.base_name}-001"
  aks_subnet_name = "snet-aks-${var.environment}-${var.location_code}-001"
  agw_subnet_name = "snet-agw-${var.environment}-${var.location_code}-001"
  pe_subnet_name = "snet-pe-${var.environment}-${var.location_code}-001"
  
  # AKS
  aks_name = "aks-${local.base_name}-001"
  
  # Storage (no hyphens, lowercase)
  storage_name = "st${var.environment}${var.project}${var.location_code}${random_string.suffix.result}"
  
  # Key Vault (check length limit)
  key_vault_name = "kv-${var.environment}-${var.project}-${var.location_code}-${random_string.suffix.result}"
  
  # SQL Server
  sql_server_name = "sql-${local.base_name}-${random_string.suffix.result}"
}
```

## Naming Rules and Restrictions Summary

### Length Limits
- **Resource Group**: 1-90 characters
- **Storage Account**: 3-24 characters (alphanumeric only)
- **Key Vault**: 3-24 characters
- **Virtual Network**: 2-64 characters
- **AKS Cluster**: 1-63 characters
- **SQL Server**: 1-63 characters

### Character Restrictions
- **Hyphens allowed**: Most resources except Storage Account
- **Case sensitivity**: Generally case-insensitive
- **Special characters**: Usually limited to hyphens and underscores
- **Numbers**: Allowed in most resources

## Best Practices

### 1. Consistency
- Use the same naming pattern across all environments
- Maintain consistent abbreviations
- Apply naming standards to all team members

### 2. Readability
- Use descriptive names that indicate purpose
- Include environment and location information
- Use delimiters for better readability

### 3. Scalability
- Include instance numbers for future scaling
- Use consistent environment codes
- Plan for multiple regions and projects

### 4. Governance
- Document naming standards
- Use Azure Policy to enforce naming conventions
- Regular audits of naming compliance
- Use Azure Naming Tool for standardization

### 5. Automation
```hcl
# Example of automated naming validation
resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.location
  
  lifecycle {
    precondition {
      condition     = length(local.resource_group_name) <= 90
      error_message = "Resource group name exceeds 90 character limit."
    }
  }
  
  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}
```

This naming convention ensures consistency, compliance with Azure naming rules, and provides clear identification of resources across the infrastructure.