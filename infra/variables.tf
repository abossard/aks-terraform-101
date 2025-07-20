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

variable "node_count" {
  description = "Initial number of nodes in the default node pool"
  type        = number
  default     = 3
}

variable "min_node_count" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 10
}

variable "node_vm_size" {
  description = "Virtual machine size for AKS nodes"
  type        = string
  default     = "Standard_D4s_v3"
}

# Security Configuration
variable "sql_admin_username" {
  description = "SQL Server administrator username"
  type        = string
  default     = "sqladmin"
  sensitive   = true
}

variable "sql_admin_password" {
  description = "SQL Server administrator password"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.sql_admin_password) >= 12
    error_message = "SQL admin password must be at least 12 characters long."
  }
}

variable "sql_azuread_admin_login" {
  description = "Azure AD admin login for SQL Server"
  type        = string
  default     = "sql-admins"
}

variable "sql_azuread_admin_object_id" {
  description = "Azure AD admin object ID for SQL Server"
  type        = string
}

variable "security_email" {
  description = "Email address for security notifications"
  type        = string
}

# Application Configuration
variable "app_namespace" {
  description = "Kubernetes namespace for the application"
  type        = string
  default     = "aks-app"
}

variable "app_service_account" {
  description = "Kubernetes service account name for the application"
  type        = string
  default     = "workload-identity-sa"
}

# SSL Configuration
variable "ssl_cert_password" {
  description = "Password for SSL certificate"
  type        = string
  sensitive   = true
  default     = ""
}

# Feature Flags
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