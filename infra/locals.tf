# Local Values for Naming and Configuration
locals {
  # Common naming components
  base_name = "${var.environment}-${var.project}-${var.location_code}"

  # Resource naming (following CAF conventions)
  resource_group_name = "rg-${local.base_name}-001"

  # Networking
  vnet_name                     = "vnet-${local.base_name}-001"
  app_gateway_subnet_name       = "snet-agw-${var.environment}-${var.location_code}-001"
  firewall_subnet_name          = "AzureFirewallSubnet" # Fixed name required
  private_endpoints_subnet_name = "snet-pe-${var.environment}-${var.location_code}-001"

  # Network Security Groups
  app_gateway_nsg_name = "nsg-agw-${var.environment}-${var.location_code}-001"
  pe_nsg_name          = "nsg-pe-${var.environment}-${var.location_code}-001"

  # Global resources
  log_analytics_name = "log-aks-${var.environment}-${var.location_code}-001"

  # Cluster-specific configurations
  cluster_configs = {
    for k, v in var.clusters : k => merge(v, {
      # AKS naming
      aks_name = "aks-${var.environment}-${var.project}-${v.name_suffix}-${var.location_code}-001"

      # Networking
      subnet_name           = "snet-${v.name_suffix}-${var.environment}-${var.location_code}-001"
      nsg_name              = "nsg-${v.name_suffix}-${var.environment}-${var.location_code}-001"
      apiserver_subnet_name = "snet-apiserver-${v.name_suffix}-${var.environment}-${var.location_code}-001"
      apiserver_nsg_name    = "nsg-apiserver-${v.name_suffix}-${var.environment}-${var.location_code}-001"

      # Deterministic cluster index and per-cluster apiserver CIDR (/28s within parent /24)
      cluster_index  = index(local.cluster_keys_sorted, k)
      apiserver_cidr = cidrsubnet(local.apiserver_parent_cidr, 4, index(local.cluster_keys_sorted, k))

      # Reserved internal IPs for NGINX ingress
      nginx_internal_ip = cidrhost(v.subnet_cidr, 100)

      # Workload identity
      workload_identity_name = "id-workload-${v.name_suffix}-${var.environment}-${var.location_code}-001"

      # AKS control plane identity (user-assigned) for custom resource operations
      aks_control_plane_identity_name = "id-aksctrl-${v.name_suffix}-${var.environment}-${var.location_code}-001"
    })
  }

  # Application Gateway
  app_gateway_pip_name = "pip-agw-${var.environment}-${var.location_code}-001"
  app_gateway_name     = "agw-main-${var.environment}-${var.location_code}-001"

  # Azure Firewall
  firewall_pip_name         = "pip-fw-${var.environment}-${var.location_code}-001"
  firewall_name             = "fw-hub-${var.environment}-${var.location_code}-001"
  firewall_policy_name      = "fwpol-main-${var.environment}-${var.location_code}-001"
  firewall_route_table_name = "rt-fw-${var.environment}-${var.location_code}-001"

  # Storage (no hyphens, lowercase, alphanumeric only)
  storage_name = "st${var.environment}${var.project}${var.location_code}${random_string.unique_suffix.result}"

  # Key Vault (3-24 characters, alphanumeric and hyphens only)
  key_vault_name = "kv-${var.environment}${var.project}${random_string.unique_suffix.result}"

  # SQL Server
  sql_server_name   = "sql-main-${var.environment}-${var.location_code}-${random_string.unique_suffix.result}"
  sql_database_name = "sqldb-app-${var.environment}-${var.location_code}"

  # Private Endpoints
  key_vault_pe_name = "pe-kv-${var.environment}-${var.location_code}-001"
  storage_pe_name   = "pe-st-${var.environment}-${var.location_code}-001"
  sql_pe_name       = "pe-sql-${var.environment}-${var.location_code}-001"

  # Managed Identity
  workload_identity_name = "id-workload-${var.environment}-${var.location_code}-001"

  # Container Registry (if enabled)
  acr_name = "acr${var.environment}${var.project}${var.location_code}${random_string.unique_suffix.result}"

  # Subnet calculations
  app_gateway_subnet_cidr = cidrsubnet(var.vnet_address_space, 8, 1) # 10.240.1.0/24
  firewall_subnet_cidr    = cidrsubnet(var.vnet_address_space, 8, 2) # 10.240.2.0/24
  pe_subnet_cidr          = cidrsubnet(var.vnet_address_space, 8, 3) # 10.240.3.0/24

  # Automatic API server subnet allocation
  # Reserve a /24 for API server subnets at a high index to avoid collisions with typical subnets.
  # With 10.240.0.0/16 => 10.240.200.0/24
  apiserver_parent_cidr = cidrsubnet(var.vnet_address_space, 8, 200)
  # Deterministic ordering for per-cluster /27 allocations
  cluster_keys_sorted = sort(keys(var.clusters))

  # Private DNS zones (fixed names)
  private_dns_zones = {
    key_vault    = "privatelink.vaultcore.azure.net"
    storage_blob = "privatelink.blob.core.windows.net"
    storage_file = "privatelink.file.core.windows.net"
    sql_database = "privatelink.database.windows.net"
  }

  # Storage endpoints configuration
  storage_endpoints = {
    blob = {
      subresource = "blob"
      dns_zone    = "storage_blob"
    }
    file = {
      subresource = "file"
      dns_zone    = "storage_file"
    }
  }

  # Common security rules for NSGs
  common_nsg_rules = {
    allow_vnet_inbound = {
      priority                   = 1100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "VirtualNetwork"
    }
    allow_vnet_outbound = {
      priority                   = 1100
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "VirtualNetwork"
    }
    allow_internet_outbound = {
      priority                   = 1000
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "Internet"
    }
  }

  # Password configurations
  password_configs = {
    sql_admin = {
      length           = 20
      min_upper        = 2
      min_lower        = 2
      min_numeric      = 2
      min_special      = 2
      override_special = "!@#$%&*()-_=+[]{}|;:,.<>?"
      secret_name      = "sql-admin-password"
    }
    ssl_cert = {
      length           = 16
      min_upper        = 1
      min_lower        = 1
      min_numeric      = 1
      min_special      = 1
      override_special = "!@#$%&*()-_=+[]{}|;:,.<>?"
      secret_name      = "ssl-certificate-password"
    }
  }

  # Common tags (stable; avoid time-based or conflicting keys)
  # - Use var.tags as the source of truth for Environment/Project/Location
  # - Add only deterministic computed tags here
  common_tags = merge(var.tags, {
    FirewallMode = var.firewall_enforcement_enabled ? "Enforcement" : "Audit"
    DeployedBy   = coalesce(var.security_email, "terraform-deployment")
  })

  # Auto-detected user information with fallbacks
  detected_user_email = coalesce(
    var.security_email,
    "admin@example.com" # Default fallback if not provided
  )

  detected_sql_admin_login = coalesce(
    var.sql_azuread_admin_login,
    local.detected_user_email
  )

  detected_sql_admin_object_id = coalesce(
    var.sql_azuread_admin_object_id,
    data.azurerm_client_config.current.object_id
  )

  # Applications: sanitize and derive per-app naming helpers
  applications_normalized = [for a in var.applications : lower(trimspace(a))]

  # Valid storage account chars (lowercase alphanumeric only). We'll sanitize per usage
  app_map = {
    for a in local.applications_normalized : a => {
      # Short code for names where brevity matters
      short = replace(replace(replace(a, "-", ""), "_", ""), " ", "")
      # CAF-ish base name fragment
      base = "${a}-${var.environment}-${var.location_code}"
      # Common tags with App
      tags = merge(local.common_tags, { App = a })
    }
  }

  # Helper to build a storage-account-safe name per app (must be 3-24, lowercase, alnum only)
  # Final composition will be st + project + env + app short + loc + suffix
  storage_name_parts = {
    for a, v in local.app_map : a => {
      # components are already sanitized: project/env/location_code are alphanumeric; v.short is alphanumeric
      prefix = lower("st${var.project}${var.environment}${v.short}${var.location_code}")
    }
  }
}