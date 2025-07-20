# Local Values for Naming and Configuration
locals {
  # Common naming components
  base_name = "${var.environment}-${var.project}-${var.location_code}"

  # Resource naming (following CAF conventions)
  resource_group_name = "rg-${local.base_name}-001"

  # Networking
  vnet_name                     = "vnet-${local.base_name}-001"
  aks_subnet_name               = "snet-aks-${var.environment}-${var.location_code}-001"
  app_gateway_subnet_name       = "snet-agw-${var.environment}-${var.location_code}-001"
  firewall_subnet_name          = "AzureFirewallSubnet" # Fixed name required
  private_endpoints_subnet_name = "snet-pe-${var.environment}-${var.location_code}-001"

  # Network Security Groups
  aks_nsg_name         = "nsg-aks-${var.environment}-${var.location_code}-001"
  app_gateway_nsg_name = "nsg-agw-${var.environment}-${var.location_code}-001"
  pe_nsg_name          = "nsg-pe-${var.environment}-${var.location_code}-001"

  # AKS
  aks_name           = "aks-${local.base_name}-001"
  log_analytics_name = "log-aks-${var.environment}-${var.location_code}-001"

  # Application Gateway
  app_gateway_pip_name = "pip-agw-${var.environment}-${var.location_code}-001"
  app_gateway_name     = "agw-main-${var.environment}-${var.location_code}-001"

  # Azure Firewall
  firewall_pip_name         = "pip-fw-${var.environment}-${var.location_code}-001"
  firewall_name             = "fw-hub-${var.environment}-${var.location_code}-001"
  firewall_policy_name      = "fwpol-main-${var.environment}-${var.location_code}-001"
  firewall_route_table_name = "rt-fw-${var.environment}-${var.location_code}-001"

  # Storage (no hyphens, lowercase, alphanumeric only)
  storage_name = "st${var.environment}${var.project}${var.location_code}${random_string.suffix.result}"

  # Key Vault (15-24 characters)
  key_vault_name = "kv-${var.environment}-${var.project}-${var.location_code}-${random_string.suffix.result}"

  # SQL Server
  sql_server_name   = "sql-main-${var.environment}-${var.location_code}-${random_string.suffix.result}"
  sql_database_name = "sqldb-app-${var.environment}-${var.location_code}"

  # Private Endpoints
  key_vault_pe_name = "pe-kv-${var.environment}-${var.location_code}-001"
  storage_pe_name   = "pe-st-${var.environment}-${var.location_code}-001"
  sql_pe_name       = "pe-sql-${var.environment}-${var.location_code}-001"

  # Managed Identity
  workload_identity_name = "id-workload-${var.environment}-${var.location_code}-001"

  # Container Registry (if enabled)
  acr_name = "acr${var.environment}${var.project}${var.location_code}${random_string.suffix.result}"

  # Subnet calculations
  aks_subnet_cidr         = cidrsubnet(var.vnet_address_space, 8, 0) # 10.240.0.0/24
  app_gateway_subnet_cidr = cidrsubnet(var.vnet_address_space, 8, 1) # 10.240.1.0/24
  firewall_subnet_cidr    = cidrsubnet(var.vnet_address_space, 8, 2) # 10.240.2.0/24
  pe_subnet_cidr          = cidrsubnet(var.vnet_address_space, 8, 3) # 10.240.3.0/24

  # IP calculations
  nginx_internal_ip = cidrhost(local.aks_subnet_cidr, 100) # 10.240.0.100

  # Private DNS zones (fixed names)
  key_vault_dns_zone    = "privatelink.vaultcore.azure.net"
  storage_blob_dns_zone = "privatelink.blob.core.windows.net"
  storage_file_dns_zone = "privatelink.file.core.windows.net"
  sql_dns_zone          = "privatelink.database.windows.net"

  # Common tags
  common_tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project
    Location    = var.location
  })
}