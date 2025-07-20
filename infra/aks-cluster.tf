# AKS Cluster Layer
# AKS with CNI Overlay, Cilium, and Workload Identity

# User-Assigned Managed Identity for Workloads
resource "azurerm_user_assigned_identity" "workload_identity" {
  name                = local.workload_identity_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

# Container Registry (optional)
resource "azurerm_container_registry" "main" {
  count               = var.enable_container_registry ? 1 : 0
  name                = local.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Premium"
  admin_enabled       = false

  # Disable public network access
  public_network_access_enabled = false

  network_rule_set {
    default_action = "Deny"
  }

  tags = local.common_tags
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = local.aks_name
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

    auto_scaling_enabled = true
    min_count            = var.min_node_count
    max_count            = var.max_node_count

    # Node pool configuration
    os_disk_size_gb = 100
    os_disk_type    = "Managed"
    os_sku          = "Ubuntu"

    # Enable host encryption
    host_encryption_enabled = true

    # Enable node public IP
    node_public_ip_enabled = false

    upgrade_settings {
      max_surge = "10%"
    }
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
    outbound_type       = "userDefinedRouting" # Route through firewall
  }

  # Enable Azure Key Vault Secrets Provider (CSI Driver)
  key_vault_secrets_provider {
    secret_rotation_enabled  = var.enable_secret_rotation
    secret_rotation_interval = var.secret_rotation_interval
  }

  identity {
    type = "SystemAssigned"
  }

  azure_active_directory_role_based_access_control {
    admin_group_object_ids = []
    azure_rbac_enabled     = true
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  # Maintenance window
  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = "Sunday"
    start_time  = "00:00"
    utc_offset  = "+00:00"
  }

  maintenance_window_node_os {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = "Sunday"
    start_time  = "00:00"
    utc_offset  = "+00:00"
  }

  # Auto-scaler profile
  auto_scaler_profile {
    balance_similar_node_groups      = false
    expander                         = "random"
    max_graceful_termination_sec     = "600"
    max_node_provisioning_time       = "15m"
    max_unready_nodes                = 3
    max_unready_percentage           = 45
    new_pod_scale_up_delay           = "10s"
    scale_down_delay_after_add       = "10m"
    scale_down_delay_after_delete    = "10s"
    scale_down_delay_after_failure   = "3m"
    scan_interval                    = "10s"
    scale_down_unneeded              = "10m"
    scale_down_unready               = "20m"
    scale_down_utilization_threshold = "0.5"
    empty_bulk_delete_max            = "10"
    skip_nodes_with_local_storage    = false
    skip_nodes_with_system_pods      = true
  }

  tags = local.common_tags

  # Implicit dependency through subnet reference that has route table association
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

# Grant ACR access to AKS (if ACR is enabled)
resource "azurerm_role_assignment" "aks_acr_pull" {
  count                = var.enable_container_registry ? 1 : 0
  scope                = azurerm_container_registry.main[0].id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

# Federated Identity Credentials
resource "azurerm_federated_identity_credential" "default_service_account" {
  name                = "fc-default-${var.environment}-${var.project}"
  resource_group_name = azurerm_resource_group.main.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.main.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.workload_identity.id
  subject             = "system:serviceaccount:default:workload-identity-sa"
}

resource "azurerm_federated_identity_credential" "app_service_account" {
  name                = "fc-app-${var.environment}-${var.project}"
  resource_group_name = azurerm_resource_group.main.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.main.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.workload_identity.id
  subject             = "system:serviceaccount:${var.app_namespace}:${var.app_service_account}"
}

resource "azurerm_federated_identity_credential" "csi_driver" {
  name                = "fc-csi-${var.environment}-${var.project}"
  resource_group_name = azurerm_resource_group.main.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.main.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.workload_identity.id
  subject             = "system:serviceaccount:kube-system:secrets-store-csi-driver"
}

# Kubernetes Resources
# Create namespace for application
resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = var.app_namespace
  }

  # Implicit dependency through app_namespace variable reference
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

  # Implicit dependencies through namespace and identity references
}

# SecretProviderClass for Key Vault integration
# Note: This will be applied after the cluster is created using null_resource
resource "null_resource" "secret_provider_class" {
  triggers = {
    cluster_id               = azurerm_kubernetes_cluster.main.id
    workload_identity        = azurerm_user_assigned_identity.workload_identity.client_id
    key_vault_name           = azurerm_key_vault.main.name
    namespace                = kubernetes_namespace.app_namespace.metadata[0].name
    key_vault_access         = azurerm_role_assignment.workload_identity_key_vault.id
    database_secret          = azurerm_key_vault_secret.database_connection.id
    storage_secret           = azurerm_key_vault_secret.storage_connection.id
    private_endpoint_ready   = azurerm_private_endpoint.key_vault.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Wait for cluster to be ready
      az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name} --overwrite-existing --admin
      
      # Create SecretProviderClass
      cat <<EOF | kubectl apply -f -
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-keyvault-secrets
  namespace: ${var.app_namespace}
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "false"
    userAssignedIdentityID: ${azurerm_user_assigned_identity.workload_identity.client_id}
    keyvaultName: ${azurerm_key_vault.main.name}
    tenantId: ${data.azurerm_client_config.current.tenant_id}
    objects: |
      array:
        - |
          objectName: database-connection-string
          objectType: secret
          objectVersion: ""
        - |
          objectName: storage-account-key
          objectType: secret
          objectVersion: ""
  secretObjects:
  - secretName: app-secrets
    type: Opaque
    data:
    - objectName: database-connection-string
      key: connectionString
    - objectName: storage-account-key
      key: storageKey
EOF
    EOT
  }

  # Implicit dependencies through triggers that reference all required resources
}

# Sample secrets in Key Vault
resource "azurerm_key_vault_secret" "database_connection" {
  name         = "database-connection-string"
  value        = "Server=${azurerm_mssql_server.main.fully_qualified_domain_name};Database=${azurerm_mssql_database.main.name};Authentication=Active Directory Managed Identity;User Id=${azurerm_user_assigned_identity.workload_identity.client_id};"
  key_vault_id = azurerm_key_vault.main.id
  
  # Need explicit dependency since Key Vault is private and needs endpoint ready
  depends_on = [azurerm_private_endpoint.key_vault]
}

resource "azurerm_key_vault_secret" "storage_connection" {
  name         = "storage-account-key"
  value        = azurerm_storage_account.main.primary_access_key
  key_vault_id = azurerm_key_vault.main.id
  
  # Need explicit dependency since Key Vault is private and needs endpoint ready
  depends_on = [azurerm_private_endpoint.key_vault]
}