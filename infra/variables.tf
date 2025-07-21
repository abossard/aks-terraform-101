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
    condition = var.sql_azuread_admin_login == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.sql_azuread_admin_login))
    error_message = "SQL Azure AD admin login must be empty (auto-detect) or a valid email address."
  }
}

variable "sql_azuread_admin_object_id" {
  description = "Azure AD admin object ID for SQL Server (auto-detected from current user if not provided)"
  type        = string
  default     = ""
  validation {
    condition = var.sql_azuread_admin_object_id == "" || can(regex("^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$", var.sql_azuread_admin_object_id))
    error_message = "SQL Azure AD admin object ID must be empty (auto-detect) or a valid UUID format."
  }
}

variable "security_email" {
  description = "Email address for security notifications (auto-detected from current user if not provided)"
  type        = string
  default     = ""
  validation {
    condition = var.security_email == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.security_email))
    error_message = "Security email must be empty (auto-detect) or a valid email address."
  }
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

# SSL Configuration (Auto-generated)
# SSL certificate password is now auto-generated - no variable needed

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