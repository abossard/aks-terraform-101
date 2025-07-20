# Terraform Variables Configuration
# Real deployment configuration

# Core Configuration
environment   = "prod"
project      = "aks101"
location     = "East US 2"
location_code = "eus2"

# Network Configuration
vnet_address_space = "10.240.0.0/16"
pod_cidr          = "192.168.0.0/16"
service_cidr      = "172.16.0.0/16"
dns_service_ip    = "172.16.0.10"

# AKS Configuration
kubernetes_version = "1.28.5"
node_count        = 3
min_node_count    = 1
max_node_count    = 10
node_vm_size      = "Standard_D4s_v3"

# SQL Server Configuration (REQUIRED)
sql_admin_username         = "sqladmin"
sql_admin_password         = "AKSDemo123456789!"  # Strong password for demo
sql_azuread_admin_login    = "anbossar@microsoft.com"
sql_azuread_admin_object_id = "c64dabd5-242b-481b-ac5d-92be5c683e9f"  # Current user object ID

# Security Configuration (REQUIRED)
security_email = "anbossar@microsoft.com"  # Current user email

# Application Configuration
app_namespace        = "aks-app"
app_service_account = "workload-identity-sa"

# SSL Configuration
ssl_cert_password = "demo123!"  # Demo certificate password

# Feature Flags
enable_container_registry = true
enable_secret_rotation    = true
secret_rotation_interval  = "2m"

# Tags
tags = {
  ManagedBy   = "terraform"
  Project     = "aks-secure-baseline"
  Environment = "production"
  Owner       = "anbossar"
  Demo        = "true"
  Location    = "East US 2"
}