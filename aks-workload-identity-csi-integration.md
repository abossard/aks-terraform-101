# AKS Workload Identity and CSI Driver Integration - Terraform Configuration

## Overview
AKS Workload Identity enables pods to authenticate to Azure services using Kubernetes service accounts through OpenID Connect (OIDC) federation, eliminating the need for stored credentials.

## Core Components

### 1. AKS Cluster with Workload Identity Enabled

```hcl
resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${var.environment}-${var.project}-${var.location_code}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "aks-${var.environment}-${var.project}-${var.location_code}"
  kubernetes_version  = var.kubernetes_version

  # Enable OIDC Issuer and Workload Identity (required for workload identity)
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name           = "default"
    node_count     = var.node_count
    vm_size        = var.node_vm_size
    vnet_subnet_id = azurerm_subnet.aks.id
    zones          = ["1", "2", "3"]
    
    enable_auto_scaling = true
    min_count          = var.min_node_count
    max_count          = var.max_node_count
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_dataplane   = "cilium"
    pod_cidr           = var.pod_cidr
    service_cidr       = var.service_cidr
    dns_service_ip     = var.dns_service_ip
    outbound_type      = "userDefinedRouting"
  }

  # Enable Azure Key Vault Secrets Provider (CSI Driver)
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  identity {
    type = "SystemAssigned"
  }

  azure_active_directory_role_based_access_control {
    managed                = true
    azure_rbac_enabled     = true
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }
}
```

### 2. User-Assigned Managed Identity for Workloads

```hcl
# User-Assigned Managed Identity for application workloads
resource "azurerm_user_assigned_identity" "workload_identity" {
  name                = "id-${var.environment}-${var.project}-${var.location_code}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# Grant Key Vault access to the workload identity
resource "azurerm_role_assignment" "workload_identity_key_vault" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.workload_identity.principal_id
}

# Grant Storage access to the workload identity
resource "azurerm_role_assignment" "workload_identity_storage" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.workload_identity.principal_id
}

# Grant SQL Database access to the workload identity
resource "azurerm_role_assignment" "workload_identity_sql" {
  scope                = azurerm_mssql_database.main.id
  role_definition_name = "SQL DB Contributor"
  principal_id         = azurerm_user_assigned_identity.workload_identity.principal_id
}
```

### 3. Federated Identity Credentials

```hcl
# Federated Identity Credential for default service account
resource "azurerm_federated_identity_credential" "default_service_account" {
  name                = "fc-default-${var.environment}-${var.project}"
  resource_group_name = azurerm_resource_group.main.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.main.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.workload_identity.id
  subject             = "system:serviceaccount:default:workload-identity-sa"
}

# Federated Identity Credential for application namespace
resource "azurerm_federated_identity_credential" "app_service_account" {
  name                = "fc-app-${var.environment}-${var.project}"
  resource_group_name = azurerm_resource_group.main.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.main.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.workload_identity.id
  subject             = "system:serviceaccount:${var.app_namespace}:${var.app_service_account}"
}

# Federated Identity Credential for CSI driver
resource "azurerm_federated_identity_credential" "csi_driver" {
  name                = "fc-csi-${var.environment}-${var.project}"
  resource_group_name = azurerm_resource_group.main.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.main.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.workload_identity.id
  subject             = "system:serviceaccount:kube-system:secrets-store-csi-driver"
}
```

### 4. Kubernetes Resources (applied via Terraform)

```hcl
# Create namespace for application
resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = var.app_namespace
  }
  
  depends_on = [azurerm_kubernetes_cluster.main]
}

# Service Account with workload identity annotations
resource "kubernetes_service_account" "workload_identity" {
  metadata {
    name      = var.app_service_account
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
    
    annotations = {
      "azure.workload.identity/client-id" = azurerm_user_assigned_identity.workload_identity.client_id
      "azure.workload.identity/tenant-id" = data.azurerm_client_config.current.tenant_id
    }
    
    labels = {
      "azure.workload.identity/use" = "true"
    }
  }
}
```

### 5. CSI Driver Configuration

```hcl
# SecretProviderClass for Key Vault integration
resource "kubernetes_manifest" "secret_provider_class" {
  manifest = {
    apiVersion = "secrets-store.csi.x-k8s.io/v1"
    kind       = "SecretProviderClass"
    
    metadata = {
      name      = "azure-keyvault-secrets"
      namespace = kubernetes_namespace.app_namespace.metadata[0].name
    }
    
    spec = {
      provider = "azure"
      
      parameters = {
        usePodIdentity         = "false"
        useVMManagedIdentity   = "false"
        userAssignedIdentityID = azurerm_user_assigned_identity.workload_identity.client_id
        keyvaultName          = azurerm_key_vault.main.name
        tenantId              = data.azurerm_client_config.current.tenant_id
        
        objects = yamlencode([
          {
            objectName = "database-connection-string"
            objectType = "secret"
            objectVersion = ""
          },
          {
            objectName = "storage-account-key"
            objectType = "secret"
            objectVersion = ""
          },
          {
            objectName = "ssl-certificate"
            objectType = "cert"
            objectVersion = ""
          }
        ])
      }
      
      # Optional: Sync with Kubernetes secrets
      secretObjects = [
        {
          secretName = "app-secrets"
          type       = "Opaque"
          data = [
            {
              objectName = "database-connection-string"
              key        = "connectionString"
            },
            {
              objectName = "storage-account-key"
              key        = "storageKey"
            }
          ]
        }
      ]
    }
  }
  
  depends_on = [
    azurerm_kubernetes_cluster.main,
    kubernetes_namespace.app_namespace
  ]
}
```

### 6. Sample Application Deployment

```hcl
# Sample deployment using workload identity
resource "kubernetes_deployment" "sample_app" {
  metadata {
    name      = "sample-app"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
  }
  
  spec {
    replicas = 2
    
    selector {
      match_labels = {
        app = "sample-app"
      }
    }
    
    template {
      metadata {
        labels = {
          app = "sample-app"
          "azure.workload.identity/use" = "true"
        }
      }
      
      spec {
        service_account_name = kubernetes_service_account.workload_identity.metadata[0].name
        
        container {
          name  = "app"
          image = "nginx:latest"
          
          volume_mount {
            name       = "secrets-store"
            mount_path = "/mnt/secrets-store"
            read_only  = true
          }
          
          env {
            name = "AZURE_CLIENT_ID"
            value = azurerm_user_assigned_identity.workload_identity.client_id
          }
          
          env {
            name = "AZURE_TENANT_ID"
            value = data.azurerm_client_config.current.tenant_id
          }
        }
        
        volume {
          name = "secrets-store"
          
          csi {
            driver    = "secrets-store.csi.k8s.io"
            read_only = true
            
            volume_attributes = {
              secretProviderClass = kubernetes_manifest.secret_provider_class.manifest.metadata.name
            }
          }
        }
      }
    }
  }
}
```

### 7. Required Variables

```hcl
variable "app_namespace" {
  description = "Kubernetes namespace for the application"
  type        = string
  default     = "app"
}

variable "app_service_account" {
  description = "Kubernetes service account name for the application"
  type        = string
  default     = "workload-identity-sa"
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
```

### 8. Key Vault Secrets (for testing)

```hcl
# Sample secrets in Key Vault
resource "azurerm_key_vault_secret" "database_connection" {
  name         = "database-connection-string"
  value        = "Server=${azurerm_mssql_server.main.fully_qualified_domain_name};Database=${azurerm_mssql_database.main.name};Authentication=Active Directory Managed Identity;User Id=${azurerm_user_assigned_identity.workload_identity.client_id};"
  key_vault_id = azurerm_key_vault.main.id
  
  depends_on = [azurerm_private_endpoint.key_vault]
}

resource "azurerm_key_vault_secret" "storage_connection" {
  name         = "storage-account-key"
  value        = azurerm_storage_account.main.primary_access_key
  key_vault_id = azurerm_key_vault.main.id
  
  depends_on = [azurerm_private_endpoint.key_vault]
}
```

## Outputs for Reference

```hcl
output "aks_oidc_issuer_url" {
  description = "OIDC Issuer URL for the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "workload_identity_client_id" {
  description = "Client ID of the workload identity"
  value       = azurerm_user_assigned_identity.workload_identity.client_id
}

output "workload_identity_principal_id" {
  description = "Principal ID of the workload identity"
  value       = azurerm_user_assigned_identity.workload_identity.principal_id
}

output "sample_service_account_namespace" {
  description = "Namespace for the sample service account"
  value       = kubernetes_namespace.app_namespace.metadata[0].name
}
```

## Configuration Best Practices

### 1. Security
- **Least Privilege**: Assign minimal required permissions to managed identities
- **Namespace Isolation**: Use separate namespaces for different applications
- **Secret Rotation**: Enable automatic secret rotation
- **RBAC**: Use Azure RBAC for fine-grained access control

### 2. Monitoring
```hcl
# Diagnostic settings for workload identity
resource "azurerm_monitor_diagnostic_setting" "workload_identity" {
  name                       = "workload-identity-diagnostics"
  target_resource_id         = azurerm_user_assigned_identity.workload_identity.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  metric {
    category = "AllMetrics"
  }
}
```

### 3. Validation Steps
1. **OIDC Issuer**: Verify `oidc_issuer_url` is populated
2. **Federated Credentials**: Check that subjects match service account patterns
3. **Pod Identity**: Verify pods have correct annotations and labels
4. **Secret Access**: Test that secrets are mounted and accessible
5. **Azure Access**: Verify pods can authenticate to Azure services

## Common Issues and Solutions

### 1. Token Exchange Failures
- **Issue**: `azure.workload.identity/client-id` annotation missing
- **Solution**: Ensure service account has correct annotations

### 2. Permission Denied
- **Issue**: Managed identity lacks required permissions
- **Solution**: Assign appropriate Azure RBAC roles

### 3. Secret Mounting Issues
- **Issue**: CSI driver fails to mount secrets
- **Solution**: Verify SecretProviderClass configuration and network access to Key Vault

### 4. OIDC Configuration
- **Issue**: Federated identity credential subject mismatch
- **Solution**: Ensure subject format matches: `system:serviceaccount:<namespace>:<service-account>`

This configuration provides a complete setup for AKS workload identity with CSI driver integration, enabling secure, credential-free access to Azure services from Kubernetes workloads.