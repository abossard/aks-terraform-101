# Terraform AzureRM Provider: AKS with CNI Overlay and Cilium Configuration

## Latest Configuration (2025)

### Terraform Resource Configuration

```hcl
resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                = "default"
    node_count          = var.node_count
    vm_size             = var.node_vm_size
    vnet_subnet_id      = azurerm_subnet.aks.id
    zones               = ["1", "2", "3"]
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

### Required Variables

```hcl
variable "pod_cidr" {
  description = "Pod CIDR for overlay network"
  type        = string
  default     = "192.168.0.0/16"
  validation {
    condition = can(cidrhost(var.pod_cidr, 0))
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
```

## Key Configuration Points

### Network Plugin Configuration
- **network_plugin**: Must be `"azure"`
- **network_plugin_mode**: Set to `"overlay"` for CNI Overlay
- **network_policy**: Set to `"cilium"` for Cilium policies
- **network_dataplane**: Set to `"cilium"` for eBPF data plane

### CIDR Requirements
1. **Pod CIDR**: Private IP range (RFC 1918 recommended)
   - Must not overlap with cluster subnet
   - Must not overlap with peered VNets
   - Default: `10.244.0.0/16`

2. **Service CIDR**: Kubernetes services network
   - Must not overlap with Pod CIDR or VNet
   - Default: `10.0.0.0/16`

3. **DNS Service IP**: First usable IP in service CIDR
   - Must be within service CIDR range
   - Typically `.10` of service CIDR

### Limitations and Constraints
- Maximum 250 pods per node
- Scale up to 5000 nodes
- Linux-only support for Cilium
- No Virtual Machine Availability Sets
- No DCsv2-series VMs
- Subnet/VNet names ≤ 63 characters

### Azure CLI Equivalent
```bash
az aks create \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --pod-cidr 192.168.0.0/16 \
    --network-dataplane cilium \
    --network-policy cilium
```

## Provider Version Requirements
- AzureRM Provider: >= 3.0
- AKS API Version: >= 2022-09-02-preview
- Azure CLI: >= 2.48.1

## Benefits
- High-performance eBPF networking
- Efficient network policy enforcement
- Enhanced observability with Cilium Hubble
- Reduced VNet IP consumption
- Support for larger cluster scales