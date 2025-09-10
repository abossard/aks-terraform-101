# Core Variables
variable "environment" {
  description = "Environment designation (dev, test, prod)"
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
  description = "Azure region for resource deployment"
  type        = string
  default     = "East US"
}

variable "location_code" {
  description = "Short location identifier for naming"
  type        = string
  default     = "eus"
}

# Network Configuration
variable "vnet_address_space" {
  description = "Virtual network address space"
  type        = string
  default     = "10.240.0.0/16"
}

variable "pod_cidr" {
  description = "Pod CIDR for overlay network"
  type        = string
  default     = "192.168.0.0/16"
  validation {
    condition     = can(cidrhost(var.pod_cidr, 0))
    error_message = "Pod CIDR must be a valid CIDR block."
  }
}

variable "service_cidr" {
  description = "Service CIDR for Kubernetes services"
  type        = string
  default     = "172.16.0.0/16"
}

variable "dns_service_ip" {
  description = "DNS service IP within service CIDR"
  type        = string
  default     = "172.16.0.10"
}

# AKS Configuration
variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
  default     = "1.28.5"
}

variable "clusters" {
  description = "(Option 2) AKS cluster configurations with applications as a map (app => { namespace = ... }). Currently informational; not yet used in resources."
  type = map(object({
    name_suffix = string
    subnet_cidr = string
    min_count   = number
    max_count   = number
    vm_size     = string
    vm_size     = string
    applications = map(object({
      namespace = string
    }))
  }))
  default = {
    public = {
      name_suffix = "public"
      subnet_cidr = "10.240.0.0/24"
      min_count   = 1
      max_count   = 3
      vm_size     = "Standard_D2s_v3"
      projects = {
        mynav = {
          frontend = {namespace = "mynav-frontend"}
          backend  = {namespace = "mynav-backend"}
        }
        lcmt = {
          frontend = {namespace = "lcmt-frontend"}
          backend  = {namespace = "lcmt-backend"}
        }
      }
      applications = {
        app1 = { namespace = "frontend" }
        app2 = { namespace = "frontend" }
        app3 = { namespace = "frontendextra" }
      }
    }
    private = {
      name_suffix = "private"
      subnet_cidr = "10.240.4.0/24"
      min_count   = 1
      max_count   = 2
      vm_size     = "Standard_D2s_v3"
      applications = {
        api1 = { namespace = "backend" }
        api2 = { namespace = "backend" }
        api3 = { namespace = "backendextra" }
      }
    }
  }
}

# Security Configuration (Auto-detected or defaulted)
variable "sql_admin_username" {
  description = "SQL Server administrator username"
  type        = string
  default     = "sqladmin"
  sensitive   = true
}

# SQL password is now auto-generated - no variable needed

variable "sql_azuread_admin_login" {
  description = "Azure AD admin login for SQL Server (auto-detected from current user if not provided)"
  type        = string
  default     = ""
  validation {
    condition     = var.sql_azuread_admin_login == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.sql_azuread_admin_login))
    error_message = "SQL Azure AD admin login must be empty (auto-detect) or a valid email address."
  }
}

variable "sql_azuread_admin_object_id" {
  description = "Azure AD admin object ID for SQL Server (auto-detected from current user if not provided)"
  type        = string
  default     = ""
  validation {
    condition     = var.sql_azuread_admin_object_id == "" || can(regex("^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$", var.sql_azuread_admin_object_id))
    error_message = "SQL Azure AD admin object ID must be empty (auto-detect) or a valid UUID format."
  }
}

variable "keyvault_administrator_principal_id" {
  description = "Azure AD principal ID for Key Vault administrator (auto-detected from current user if not provided)"
  type        = string
  default     = ""
}

variable "security_email" {
  description = "Email address for security notifications (auto-detected from current user if not provided)"
  type        = string
  default     = ""
  validation {
    condition     = var.security_email == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.security_email))
    error_message = "Security email must be empty (auto-detect) or a valid email address."
  }
}

# Application Configuration
variable "app_namespace" {
  description = "Kubernetes namespace for the application"
  type        = string
  default     = "default"
}

variable "app_service_account" {
  description = "Kubernetes service account name for the application"
  type        = string
  default     = "workload-identity-sa"
}

# SSL Configuration (Auto-generated)
# SSL certificate password is now auto-generated - no variable needed

# Feature Flags
variable "enable_api_server_vnet_integration" {
  description = "Enable API Server VNet Integration (ASVNI) and create a dedicated API server subnet per cluster."
  type        = bool
  default     = true
  validation {
    condition     = can(var.enable_api_server_vnet_integration)
    error_message = "enable_api_server_vnet_integration must be true or false."
  }
}


variable "enable_private_cluster" {
  description = "Enable AKS private cluster (API server private endpoint)."
  type        = bool
  default     = false
  validation {
    condition     = can(var.enable_private_cluster)
    error_message = "enable_private_cluster must be true or false."
  }
}


variable "enable_container_registry" {
  description = "Enable Azure Container Registry"
  type        = bool
  default     = true
}

variable "enable_secret_rotation" {
  description = "Enable automatic secret rotation for CSI driver"
  type        = bool
  default     = true
}

variable "secret_rotation_interval" {
  description = "Interval for secret rotation"
  type        = string
  default     = "2m"
}

variable "firewall_enforcement_enabled" {
  description = "Enable firewall rule enforcement (true) or audit mode only (false)"
  type        = bool
  default     = false
  validation {
    condition     = can(var.firewall_enforcement_enabled)
    error_message = "Firewall enforcement must be true or false."
  }
}

variable "enable_strict_nsg_outbound_deny" {
  description = "Enable strict outbound deny rules in NSGs (requires hub/firewall setup)"
  type        = bool
  default     = false
  validation {
    condition     = can(var.enable_strict_nsg_outbound_deny)
    error_message = "Strict NSG outbound deny must be true or false."
  }
}

# Egress routing control
variable "route_egress_through_firewall" {
  description = "Route AKS egress through Azure Firewall using UDR (true) or use load balancer SNAT (false)."
  type        = bool
  default     = false
  validation {
    condition     = can(var.route_egress_through_firewall)
    error_message = "route_egress_through_firewall must be true or false."
  }
}

# VNet Peering Configuration
variable "enable_vnet_peering" {
  description = "Enable VNet peering with hub network"
  type        = bool
  default     = false
}

# DNS / Private DNS Mode Switches
variable "create_private_dns_zones" {
  description = "Create private DNS zones locally (mutually exclusive with use_external_private_dns_zones)."
  type        = bool
  default     = true
}

variable "use_external_private_dns_zones" {
  description = "Use externally managed private DNS zones (expects private_dns_config). Mutually exclusive with create_private_dns_zones."
  type        = bool
  default     = false
  validation {
    condition     = (var.create_private_dns_zones != var.use_external_private_dns_zones)
    error_message = "Exactly one of create_private_dns_zones or use_external_private_dns_zones must be true (mutually exclusive)."
  }
}

variable "hub_vnet_config" {
  description = "Hub VNet configuration for peering"
  type = object({
    subscription_id       = string
    resource_group        = string
    vnet_name             = string
    vnet_cidr             = optional(string, "10.0.0.0/16")
    allow_gateway_transit = optional(bool, false)
    use_remote_gateways   = optional(bool, false)
  })
  default = null
  validation {
    condition     = var.enable_vnet_peering == false || (var.enable_vnet_peering == true && var.hub_vnet_config != null)
    error_message = "hub_vnet_config must be provided when enable_vnet_peering is true."
  }
}

variable "vnet_peering_name" {
  description = "Name for the VNet peering connection"
  type        = string
  default     = null
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy   = "terraform"
    Project     = "aks-secure-baseline"
    Environment = "production"
  }
}

variable "mssql_allowed_ip_start" {
  description = "List of allowed IP addresses for SQL Database access"
  type        = string
  default     = "147.161.248.127"
}

variable "mssql_allowed_ip_end" {
  description = "List of allowed IP addresses for SQL Database access"
  type        = string
  default     = "147.161.248.127"
}

# Private DNS Link configuration
variable "private_dns_config" {
  description = "Private DNS configuration for linking to hub network"
  type = object({
    subscription_id       = string
    resource_group        = string
    private_dns_zone_name = map(string)
  })
  default = null
}

## DNS Servers of the VNet (empty list => Azure provided DNS)
variable "custom_dns_servers" {
  description = "Custom DNS servers for the VNet (IPv4). Leave empty list to use Azure default DNS."
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for ip in var.custom_dns_servers : can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", ip))])
    error_message = "Each custom DNS server must be a valid IPv4 address."
  }
}

# SQL Variables

# SQL Server Database SKU

variable "sqldb_sku_name" {
  description = "SKU name for the SQL Database"
  type        = string
  default     = "S1"
}

# SQL Server  Zone Redundancy

variable "sqldb_zone_redundant" {
  description = "Enable zone redundancy for SQL Server"
  type        = bool
  default     = false
}

# Variabile for managing the Short Term Retention Frequency of the SQL Server Backup

variable "stb_backup_interval_hour" {
  description = "Short-term backup interval in hours for SQL Database"
  type        = number
  default     = 12
  validation {
    condition     = var.stb_backup_interval_hour == 12 || var.stb_backup_interval_hour == 24
    error_message = "Backup interval must be between 12 or 24 hours."
  }
}

# Variabile for managing the Short Term Retention of the SQL Server Backup

variable "stb_days_of_retention" {
  description = "Short-term backup retention period in days for SQL Database"
  type        = number
  default     = 15
  validation {
    condition     = var.stb_days_of_retention >= 1 && var.stb_days_of_retention <= 90
    error_message = "Retention period must be between 1 and 90 days."
  }
}

# Long-term backup retention variables
variable "ltr_weekly_retention" {
  description = "Long-term weekly backup retention period (ISO 8601 format, e.g., P4W for 4 weeks, PT0S for disabled)"
  type        = string
  default     = "P2W"
  validation {
    condition     = can(regex("^(PT0S|P([0-9]+W))$", var.ltr_weekly_retention))
    error_message = "Weekly retention must be in ISO 8601 format (e.g., P4W for 4 weeks) or PT0S to disable."
  }
}

variable "ltr_monthly_retention" {
  description = "Long-term monthly backup retention period (ISO 8601 format, e.g., P12M for 12 months, PT0S for disabled)"
  type        = string
  default     = "PT0S"
  validation {
    condition     = can(regex("^(PT0S|P([0-9]+M))$", var.ltr_monthly_retention))
    error_message = "Monthly retention must be in ISO 8601 format (e.g., P12M for 12 months) or PT0S to disable."
  }
}

variable "ltr_yearly_retention" {
  description = "Long-term yearly backup retention period (ISO 8601 format, e.g., P5Y for 5 years, PT0S for disabled)"
  type        = string
  default     = "PT0S"
  validation {
    condition     = can(regex("^(PT0S|P([0-9]+Y))$", var.ltr_yearly_retention))
    error_message = "Yearly retention must be in ISO 8601 format (e.g., P5Y for 5 years) or PT0S to disable."
  }
}

variable "ltr_week_of_year" {
  description = "Week of the year to take the yearly backup (1-52)"
  type        = number
  default     = 1
  validation {
    condition     = var.ltr_week_of_year >= 1 && var.ltr_week_of_year <= 52
    error_message = "Week of year must be between 1 and 52."
  }
}

variable "ltr_immutable_backups_enabled" {
  description = "Enable immutable backups for long-term retention"
  type        = bool
  default     = false
}

variable "storage_replication_type" {
  description = "Storage account replication type (LRS, GRS, RAGRS, ZRS)"
  type        = string
  default     = "LRS"
  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS"], var.storage_replication_type)
    error_message = "Storage replication type must be one of: LRS, GRS, RAGRS, ZRS."
  }
}

# ------------------------------------------------------------
# Optional Feature Flags
# ------------------------------------------------------------
variable "enable_backup" {
  description = "Enable creation of Data Protection backup vault, policy and instance for app1 storage account"
  type        = bool
  # Enabled by default (user can set to false to skip all backup resources)
  default     = true
}

variable "app1_storage_account_containers" {
  description = "List of storage account container names"
  type        = list(string)
  default     = ["test1", "test2", "test3"]
}

## Note: Applications are now defined per cluster (see variable "clusters").