# AKS Cluster Layer
# AKS with CNI Overlay, Cilium, and Workload Identity

# User-Assigned Managed Identity for AKS control plane (required for custom network operations like ASVNI)
resource "azurerm_user_assigned_identity" "control_plane_identity" {
  for_each = var.clusters

  name                = local.cluster_configs[each.key].aks_control_plane_identity_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
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
  public_network_access_enabled = true

  network_rule_set {
    default_action = "Allow"
  }

}

# AKS Clusters
resource "azurerm_kubernetes_cluster" "main" {
  for_each = var.clusters

  name                = local.cluster_configs[each.key].aks_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "aks-${var.environment}-${var.project}-${each.value.name_suffix}-${var.location_code}"
  kubernetes_version  = var.kubernetes_version

  # Enable OIDC Issuer and Workload Identity (required for workload identity)
  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  local_account_disabled    = true

  default_node_pool {
    name           = "default"
    vm_size        = each.value.vm_size
    vnet_subnet_id = azurerm_subnet.clusters[each.key].id
    zones          = ["1"] # Single zone for cost savings

    auto_scaling_enabled = true
    min_count            = each.value.min_count
    max_count            = each.value.max_count

    # Minimal node configuration for cost savings  
    os_disk_type    = "Managed" # Changed from Ephemeral - doesn't fit in Standard_D2s_v3
    os_disk_size_gb = 30        # Smaller managed disk for cost savings
    os_sku          = "AzureLinux"
    max_pods        = 30 # Reduced from default 110

    # Host encryption disabled (subscription doesn't support it)
    host_encryption_enabled = false

    # Enable node public IP
    node_public_ip_enabled = false

    upgrade_settings {
      max_surge = "100%" # Faster scaling for minimal clusters
    }
  }

  service_mesh_profile {
    mode                             = "Istio"
    internal_ingress_gateway_enabled = true
    external_ingress_gateway_enabled = false
    revisions                        = ["asm-1-26"]
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_data_plane  = "cilium"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
    outbound_type       = var.route_egress_through_firewall ? "userDefinedRouting" : "loadBalancer"
  }

  # Enable Azure Key Vault Secrets Provider (CSI Driver)
  key_vault_secrets_provider {
    secret_rotation_enabled  = var.enable_secret_rotation
    secret_rotation_interval = var.secret_rotation_interval
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.control_plane_identity[each.key].id]
  }

  azure_active_directory_role_based_access_control {
    admin_group_object_ids = []
    azure_rbac_enabled     = true
  }

  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.main.id
    msi_auth_for_monitoring_enabled = true
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

  # Azure Managed Prometheus monitoring
  monitor_metrics {
    annotations_allowed = "prometheus.io/scrape,prometheus.io/path,prometheus.io/port"
    labels_allowed      = "app.kubernetes.io/name,app.kubernetes.io/instance"
  }

  # Auto-scaler profile optimized for minimal clusters
  auto_scaler_profile {
    balance_similar_node_groups      = false
    expander                         = "random"
    max_graceful_termination_sec     = "600"
    max_node_provisioning_time       = "5m" # Faster for B-series
    max_unready_nodes                = 1    # Reduced for minimal clusters
    max_unready_percentage           = 45
    new_pod_scale_up_delay           = "5s" # Faster scaling
    scale_down_delay_after_add       = "5m" # Faster scale-down
    scale_down_delay_after_delete    = "10s"
    scale_down_delay_after_failure   = "3m"
    scan_interval                    = "10s"
    scale_down_unneeded              = "5m" # Faster scale-down
    scale_down_unready               = "20m"
    scale_down_utilization_threshold = "0.5"
    empty_bulk_delete_max            = "5" # Reduced for minimal clusters
    skip_nodes_with_local_storage    = false
    skip_nodes_with_system_pods      = true
  }

  tags = local.common_tags
}

# Ensure AKS identities can manage/read networking for ILB operations
# Fixes: AuthorizationFailed on Microsoft.Network/virtualNetworks/subnets/read when creating internal LoadBalancer
resource "azurerm_role_assignment" "aks_identity_network_contributor_vnet" {
  for_each = var.clusters

  scope                = azurerm_virtual_network.main.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane_identity[each.key].principal_id
}

# Some operations may use the kubelet identity; grant it as well for safety
resource "azurerm_role_assignment" "aks_kubelet_network_contributor_vnet" {
  for_each = var.clusters

  scope                = azurerm_virtual_network.main.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.main[each.key].kubelet_identity[0].object_id
}


# Grant ACR access to AKS clusters (if ACR is enabled)
resource "azurerm_role_assignment" "aks_acr_pull" {
  for_each = var.enable_container_registry ? var.clusters : {}

  scope                = azurerm_container_registry.main[0].id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main[each.key].kubelet_identity[0].object_id
}

# Grant the current user full Kubernetes admin via Azure RBAC (cluster-wide)
resource "azurerm_role_assignment" "current_user_aks_rbac_cluster_admin" {
  for_each = azurerm_kubernetes_cluster.main

  scope                = azurerm_kubernetes_cluster.main[each.key].id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Kubernetes Resources removed - deploy manually after infrastructure is ready
# Use the following commands after deployment:
# 1. az aks get-credentials --resource-group rg-prod-aks101-eus2-001 --name aks-prod-aks101-eus2-001 --admin
# 2. kubectl create namespace aks-app
# 3. Create workload identity service account and SecretProviderClass manually

# -----------------------------------------------------------------------------
# Render ServiceAccount YAML per cluster (default namespace) for Workload Identity
# -----------------------------------------------------------------------------
locals {
  service_account_name = var.app_service_account
}

data "azurerm_client_config" "tenant" {}

# -----------------------------------------------------------------------------
# Render per-cluster Default NetworkPolicy (baseline deny with controlled egress)
# -----------------------------------------------------------------------------
locals {
  default_network_policy_manifests = {
    for k, v in var.clusters : k => templatefile(
      "${path.module}/k8s/default-networkpolicy.tmpl.yaml",
      {
        pe_subnet_cidr = local.pe_subnet_cidr
      }
    )
  }
}

resource "local_file" "default_network_policy" {
  for_each = local.default_network_policy_manifests

  content  = each.value
  filename = "${path.module}/k8s/generated/${each.key}-default-networkpolicy.yaml"
}

# -----------------------------------------------------------------------------
# Render per-cluster AKS cheatsheets (Markdown)
# -----------------------------------------------------------------------------
locals {
  cheatsheets = {
    for k, v in var.clusters : k => templatefile(
      "${path.module}/cheatsheets/aks-cheatsheet.tmpl.md",
      {
        cluster_key          = k,
        cluster_name         = local.cluster_configs[k].aks_name,
        aks_name             = local.cluster_configs[k].aks_name,
        resource_group       = azurerm_resource_group.main.name,
        app_namespace        = var.app_namespace,
        service_account_name = var.app_service_account,
        nginx_internal_ip    = local.cluster_configs[k].nginx_internal_ip,
        subnet_name          = local.cluster_configs[k].subnet_name,
        app_gw_ip            = azurerm_public_ip.app_gateway.ip_address,
        public_host          = "app.yourdomain.com"
      }
    )
  }
}

resource "local_file" "cheatsheets" {
  for_each = local.cheatsheets

  content  = each.value
  filename = "${path.module}/cheatsheets/generated/${each.key}-cheatsheet.md"
}

# -----------------------------------------------------------------------------
# Render per-cluster setup scripts (Bash)
# Connects to the cluster, applies NGINX CRD, and prints kube-system/nodes
# -----------------------------------------------------------------------------
locals {
  cluster_setup_scripts = {
    for k, v in var.clusters : k => templatefile(
      "${path.module}/scripts/cluster-setup.tmpl.sh",
      {
        cluster_name        = local.cluster_configs[k].aks_name,
        resource_group      = azurerm_resource_group.main.name,
        enable_asvni        = tostring(var.enable_api_server_vnet_integration),
        apiserver_subnet_id = var.enable_api_server_vnet_integration ? azurerm_subnet.apiserver[k].id : ""
        internal_ip         = local.cluster_configs[k].nginx_internal_ip,
        subnet_name         = local.cluster_configs[k].subnet_name
      }
    )
  }
}

resource "local_file" "cluster_setup" {
  for_each = local.cluster_setup_scripts

  content  = each.value
  filename = "${path.module}/k8s/generated/${each.key}-cluster-setup.sh"
}

# Enable API Server VNet Integration (ASVNI) using AzAPI per cluster when toggled
resource "azapi_update_resource" "aks_enable_asvni" {
  for_each    = var.enable_api_server_vnet_integration ? var.clusters : {}
  type        = "Microsoft.ContainerService/managedClusters@2024-05-01"
  resource_id = azurerm_kubernetes_cluster.main[each.key].id

  body = {
    properties = {
      apiServerAccessProfile = {
        enablePrivateCluster  = var.enable_private_cluster
        enableVnetIntegration = true
        subnetId              = azurerm_subnet.apiserver[each.key].id
      }
    }
  }

  # Ensure the control plane identity has VNet permissions before enabling ASVNI
  depends_on = [
    azurerm_role_assignment.aks_identity_network_contributor_vnet
  ]
}

# Sample secrets in Key Vault with auto-generated connection strings for each cluster
// Removed shared connection-string secrets (secretless MI). Use per-app DB names via outputs.

resource "azurerm_key_vault_secret" "storage_connection" {
  for_each = var.clusters

  name         = "storage-account-key-${each.value.name_suffix}"
  value        = azurerm_storage_account.main.primary_access_key
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [time_sleep.kv_rbac_propagation]
}