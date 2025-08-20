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

# AKS Cluster Subnets
output "cluster_subnet_ids" {
  description = "IDs of the AKS cluster subnets"
  value = {
    for k, v in azurerm_subnet.clusters : k => v.id
  }
}

output "app_gateway_subnet_id" {
  description = "ID of the Application Gateway subnet"
  value       = azurerm_subnet.app_gateway.id
}

# API Server Subnets (if enabled)
output "apiserver_subnet_ids" {
  description = "IDs of the per-cluster API server subnets (ASVNI)"
  value       = var.enable_api_server_vnet_integration ? { for k, v in azurerm_subnet.apiserver : k => v.id } : {}
}

# AKS Clusters
output "aks_clusters" {
  description = "AKS cluster information"
  value = {
    for k, v in azurerm_kubernetes_cluster.main : k => {
      name              = v.name
      id                = v.id
      fqdn              = v.fqdn
      nginx_internal_ip = local.cluster_configs[k].nginx_internal_ip
    }
  }
}

output "kubernetes_version" {
  description = "Kubernetes version for all clusters"
  value       = var.kubernetes_version
}

output "aks_oidc_issuer_urls" {
  description = "OIDC Issuer URLs for the AKS clusters"
  value = {
    for k, v in azurerm_kubernetes_cluster.main : k => v.oidc_issuer_url
  }
}

output "aks_node_resource_groups" {
  description = "Resource groups of the AKS cluster nodes"
  value = {
    for k, v in azurerm_kubernetes_cluster.main : k => v.node_resource_group
  }
}

# Workload Identity
# Workload Identities
output "workload_identities" {
  description = "Workload identity information for each cluster"
  value = {
    for k, v in azurerm_user_assigned_identity.workload_identity : k => {
      client_id    = v.client_id
      principal_id = v.principal_id
      name         = v.name
    }
  }
}

# Removed duplicate output - workload_identities already provides this information

# SQL Application Identity
output "sql_app_identity_client_id" {
  description = "Client ID of the SQL application identity"
  value       = azurerm_user_assigned_identity.sql_app_identity.client_id
}

output "sql_app_identity_principal_id" {
  description = "Principal ID of the SQL application identity"
  value       = azurerm_user_assigned_identity.sql_app_identity.principal_id
}

output "sql_app_identity_name" {
  description = "Name of the SQL application identity"
  value       = azurerm_user_assigned_identity.sql_app_identity.name
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

# NGINX Ingress Internal IPs (per cluster)
output "nginx_internal_ips" {
  description = "Static internal IP addresses reserved for NGINX Ingress Controllers"
  value = {
    for k, v in local.cluster_configs : k => v.nginx_internal_ip
  }
}

# NGINX Ingress Configuration for Kubernetes deployments
output "nginx_ingress_config" {
  description = "Configuration values for deploying NGINX ingress with static IPs"
  value = {
    for k, v in local.cluster_configs : k => {
      # Static IP for LoadBalancer service
      static_ip = v.nginx_internal_ip

      # Subnet name for Azure Load Balancer
      subnet_name = v.subnet_name

      # Required service annotations
      annotations = {
        "service.beta.kubernetes.io/azure-load-balancer-internal"        = "true"
        "service.beta.kubernetes.io/azure-load-balancer-static-ip"       = v.nginx_internal_ip
        "service.beta.kubernetes.io/azure-load-balancer-internal-subnet" = v.subnet_name
      }

      # Cluster information
      cluster_name = v.aks_name
      subnet_cidr  = var.clusters[k].subnet_cidr
    }
  }
}

# Rendered NginxIngressController manifests (per cluster)
output "nginx_controller_manifest_files" {
  description = "Paths to the generated NginxIngressController YAML files for each cluster"
  value = {
    for k, v in local_file.nginx_internal_controllers : k => v.filename
  }
}

# Rendered per-cluster AKS cheatsheets
output "aks_cheatsheets" {
  description = "Paths to the generated AKS cheatsheets (Markdown) for each cluster"
  value = {
    for k, v in local_file.cheatsheets : k => v.filename
  }
}

# Rendered per-cluster cluster setup scripts
output "cluster_setup_scripts" {
  description = "Paths to the generated per-cluster setup scripts (Bash)"
  value = {
    for k, v in local_file.cluster_setup : k => v.filename
  }
}

# Kubernetes Configuration
output "kube_config_raw" {
  description = "Raw kubeconfig for the AKS clusters"
  value = {
    for k, v in azurerm_kubernetes_cluster.main : k => v.kube_config_raw
  }
  sensitive = true
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

# Rendered ServiceAccount YAMLs (per cluster)
output "service_account_manifest_files" {
  description = "Paths to the generated ServiceAccount YAML files for each cluster"
  value = {
    for k, v in local_file.service_accounts : k => v.filename
  }
}

# Per-app: namespaces and SAs
output "app_namespaces" {
  description = "Per-app Kubernetes namespaces"
  value       = { for a, v in local.app_k8s : a => v.namespace }
}

output "app_service_accounts" {
  description = "Per-app Kubernetes service account names"
  value       = { for a, v in local.app_k8s : a => v.service_account }
}

output "app_uami_client_ids" {
  description = "Per-app user-assigned managed identity client IDs"
  value       = { for a, v in local.app_identities : a => v.client_id }
}

output "app_federated_identity_ids" {
  description = "Per-app per-cluster federated identity credential IDs"
  value = {
    for k, v in azurerm_federated_identity_credential.app : k => v.id
  }
}

# Rendered per-app ServiceAccount YAMLs (per cluster/app)
output "app_service_account_manifest_files" {
  description = "Paths to the generated per-app ServiceAccount YAML files for each cluster/app combination"
  value = {
    for k, v in local_file.app_service_accounts : k => v.filename
  }
}

output "app_kv_private_fqdns" {
  description = "Per-app Key Vault Private Endpoint FQDNs (in the privatelink zone)"
  value = {
    for a, kv_name in local.app_kv_name_map : a => "${kv_name}.${local.private_dns_zones["key_vault"]}"
  }
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
    key_vault    = azurerm_private_dns_zone.main["key_vault"].name
    storage_blob = azurerm_private_dns_zone.main["storage_blob"].name
    storage_file = azurerm_private_dns_zone.main["storage_file"].name
    sql_database = azurerm_private_dns_zone.main["sql_database"].name
  }
}

# Deployment Information
output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    resource_group = azurerm_resource_group.main.name
    location       = azurerm_resource_group.main.location

    # Dual AKS clusters
    clusters = {
      for k, v in azurerm_kubernetes_cluster.main : k => {
        name    = v.name
        vm_size = var.clusters[k].vm_size
        scaling = {
          autoscaling_enabled = true
          min_count           = var.clusters[k].min_count
          max_count           = var.clusters[k].max_count
        }
        nginx_ip = local.cluster_configs[k].nginx_internal_ip
      }
    }

    # Infrastructure
    application_gateway = azurerm_application_gateway.main.name
    azure_firewall      = azurerm_firewall.main.name
    key_vault           = azurerm_key_vault.main.name
    storage_account     = azurerm_storage_account.main.name
    sql_server          = azurerm_mssql_server.main.name
    sql_database        = azurerm_mssql_database.main.name
    log_analytics       = azurerm_log_analytics_workspace.main.name
    app_insights        = azurerm_application_insights.main.name

    # Access information
    public_ip = azurerm_public_ip.app_gateway.ip_address
    domains = {
      public_app  = "app.yourdomain.com"
      backend_api = "api.yourdomain.com (WAF restricted)"
    }

    # Features enabled
    web_app_routing_enabled = true
    prometheus_enabled      = true
    waf_enabled             = true
    firewall_mode           = var.firewall_enforcement_enabled ? "Enforcement" : "Audit"

    deployment_time = timestamp()
  }
}