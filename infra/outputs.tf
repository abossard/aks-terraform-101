# Output Values

# Resource Group
output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.main.location
}

# Networking
output "virtual_network_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "virtual_network_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = azurerm_subnet.aks.id
}

output "app_gateway_subnet_id" {
  description = "ID of the Application Gateway subnet"
  value       = azurerm_subnet.app_gateway.id
}

# AKS Cluster
output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.id
}

output "aks_cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.fqdn
}

output "aks_cluster_kubernetes_version" {
  description = "Kubernetes version of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.kubernetes_version
}

output "aks_oidc_issuer_url" {
  description = "OIDC Issuer URL for the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "aks_node_resource_group" {
  description = "Resource group of the AKS cluster nodes"
  value       = azurerm_kubernetes_cluster.main.node_resource_group
}

# Workload Identity
output "workload_identity_client_id" {
  description = "Client ID of the workload identity"
  value       = azurerm_user_assigned_identity.workload_identity.client_id
}

output "workload_identity_principal_id" {
  description = "Principal ID of the workload identity"
  value       = azurerm_user_assigned_identity.workload_identity.principal_id
}

output "workload_identity_name" {
  description = "Name of the workload identity"
  value       = azurerm_user_assigned_identity.workload_identity.name
}

# Application Gateway
output "application_gateway_name" {
  description = "Name of the Application Gateway"
  value       = azurerm_application_gateway.main.name
}

output "application_gateway_public_ip" {
  description = "Public IP address of the Application Gateway"
  value       = azurerm_public_ip.app_gateway.ip_address
}

output "application_gateway_fqdn" {
  description = "FQDN of the Application Gateway public IP"
  value       = azurerm_public_ip.app_gateway.fqdn
}

# Azure Firewall
output "azure_firewall_name" {
  description = "Name of the Azure Firewall"
  value       = azurerm_firewall.main.name
}

output "azure_firewall_private_ip" {
  description = "Private IP address of the Azure Firewall"
  value       = azurerm_firewall.main.ip_configuration[0].private_ip_address
}

output "azure_firewall_public_ip" {
  description = "Public IP address of the Azure Firewall"
  value       = azurerm_public_ip.firewall.ip_address
}

# Key Vault
output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.main.id
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

# Storage Account
output "storage_account_name" {
  description = "Name of the Storage Account"
  value       = azurerm_storage_account.main.name
}

output "storage_account_id" {
  description = "ID of the Storage Account"
  value       = azurerm_storage_account.main.id
}

output "storage_account_primary_endpoint" {
  description = "Primary endpoint of the Storage Account"
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

# SQL Server
output "sql_server_name" {
  description = "Name of the SQL Server"
  value       = azurerm_mssql_server.main.name
}

output "sql_server_fqdn" {
  description = "FQDN of the SQL Server"
  value       = azurerm_mssql_server.main.fully_qualified_domain_name
}

output "sql_database_name" {
  description = "Name of the SQL Database"
  value       = azurerm_mssql_database.main.name
}

# Container Registry (if enabled)
output "container_registry_name" {
  description = "Name of the Container Registry"
  value       = var.enable_container_registry ? azurerm_container_registry.main[0].name : null
}

output "container_registry_login_server" {
  description = "Login server of the Container Registry"
  value       = var.enable_container_registry ? azurerm_container_registry.main[0].login_server : null
}

# Log Analytics
output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.name
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

# Application Insights
output "application_insights_name" {
  description = "Name of Application Insights"
  value       = azurerm_application_insights.main.name
}

output "application_insights_instrumentation_key" {
  description = "Instrumentation key for Application Insights"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Connection string for Application Insights"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

# NGINX Ingress Internal IP
output "nginx_internal_ip" {
  description = "Internal IP address for NGINX Ingress Controller"
  value       = local.nginx_internal_ip
}

# Kubernetes Configuration
output "kube_config_raw" {
  description = "Raw kubeconfig for the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

# Application Configuration (static values since K8s resources removed)
output "app_namespace" {
  description = "Kubernetes namespace for the application"
  value       = var.app_namespace
}

output "app_service_account" {
  description = "Kubernetes service account for the application"
  value       = var.app_service_account
}

# Useful URLs and Endpoints
output "application_url" {
  description = "URL to access the application via Application Gateway"
  value       = "https://${azurerm_public_ip.app_gateway.ip_address}"
}

# Network Configuration
output "vnet_address_space" {
  description = "Address space of the virtual network"
  value       = var.vnet_address_space
}

output "pod_cidr" {
  description = "Pod CIDR for the AKS cluster"
  value       = var.pod_cidr
}

output "service_cidr" {
  description = "Service CIDR for the AKS cluster"
  value       = var.service_cidr
}

# Security Information
output "private_dns_zones" {
  description = "Private DNS zones created"
  value = {
    key_vault    = azurerm_private_dns_zone.key_vault.name
    storage_blob = azurerm_private_dns_zone.storage_blob.name
    storage_file = azurerm_private_dns_zone.storage_file.name
    sql_database = azurerm_private_dns_zone.sql_database.name
  }
}

# Deployment Information
output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    resource_group      = azurerm_resource_group.main.name
    aks_cluster         = azurerm_kubernetes_cluster.main.name
    application_gateway = azurerm_application_gateway.main.name
    azure_firewall      = azurerm_firewall.main.name
    key_vault           = azurerm_key_vault.main.name
    storage_account     = azurerm_storage_account.main.name
    sql_server          = azurerm_mssql_server.main.name
    log_analytics       = azurerm_log_analytics_workspace.main.name
    app_insights        = azurerm_application_insights.main.name
    workload_identity   = azurerm_user_assigned_identity.workload_identity.name
    nginx_internal_ip   = local.nginx_internal_ip
    public_ip           = azurerm_public_ip.app_gateway.ip_address
  }
}