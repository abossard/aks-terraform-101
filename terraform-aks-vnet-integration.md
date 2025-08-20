# AKS + VNet Integration with Terraform

This guide shows how to deploy an AKS cluster integrated with an Azure Virtual Network (VNet) using Terraform, with practical examples and source references.

## API Server VNet Integration (ASVNI)

API Server VNet Integration projects the AKS control-plane endpoint (kube-apiserver) into a dedicated subnet in your VNet. Nodes always talk to the API server over private networking without a tunnel. You can use it with public or private clusters.

Key points
- Requires a dedicated API server subnet. If you don’t supply one, AKS will create it in the node resource group.
- Works with both public and private clusters. You can toggle public access separately.
- NSG rules must allow:
  - From cluster subnet to API server subnet: TCP 443 and 4443
  - From Azure Load Balancer to API server subnet: TCP 9988
- Converting an existing cluster is a one-way change and requires an immediate cluster restart; the API server IP changes (hostname stays the same).

References
- AKS API Server VNet Integration: https://learn.microsoft.com/azure/aks/api-server-vnet-integration
- Private Link for ASVNI: https://learn.microsoft.com/azure/aks/private-apiserver-vnet-integration-cluster

### Subnet layout

- aks-nodes subnet: where your node pool lives (vnet_subnet_id on default/node pools)
- apiserver subnet: delegated/used by AKS for the control-plane VIP (ASVNI)

### How big should the API server subnet be?

- Minimum supported size: /28
  - Source: “Create an AKS cluster with API Server VNet Integration” (BYO VNet) — The minimum supported API server subnet size is a /28. Also notes AKS reserves at least 9 IPs in the subnet and running out of IPs can prevent API server scaling and cause outage.
    - https://learn.microsoft.com/azure/aks/api-server-vnet-integration#create-a-private-aks-cluster-with-api-server-vnet-integration-using-bring-your-own-vnet
- Dedicated use: You can’t use the API server subnet for other workloads, but it can be shared by multiple AKS clusters in the same VNet (per docs above).
- Practical guidance: Use /27 or larger if you want extra headroom (for example, multiple clusters sharing the same ASVNI subnet or to reduce the risk of scaling constraints). This is a sizing best practice; the official minimum remains /28.
- Reminder: Delegate the subnet to Microsoft.ContainerService/managedClusters when using BYO VNet.

---

## Terraform examples for ASVNI

Note on provider versions
- Use AzAPI to enable ASVNI until first-class support returns. See the AzureRM 4.0 upgrade guide notes in provider history.

### 1) AzureRM v4.x — enable ASVNI via AzAPI (recommended for your setup)

Create an API server subnet and then PATCH the AKS resource to enable ASVNI.

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.13"
    }
  }
}

provider "azurerm" { features {} }

# Example subnets (nodes + apiserver)
resource "azurerm_subnet" "nodes" {
  name                 = "aks-nodes"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_subnet" "apiserver" {
  name                 = "aks-apiserver"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.2.0/27"] # /28 is the minimum per docs; /27 gives headroom
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "${var.aks_name}-dns"

  identity { type = "SystemAssigned" }

  default_node_pool {
    name           = "system"
    vm_size        = "Standard_DS3_v2"
    node_count     = 3
    vnet_subnet_id = azurerm_subnet.nodes.id
  }

  network_profile {
    network_plugin    = "azure"            # or overlay if desired
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"     # or managedNATGateway / userDefinedRouting
  }

  # Combine with private cluster settings if desired:
  # private_cluster_enabled               = true
  # private_dns_zone_id                   = var.private_dns_zone_id # or "system"
  # private_cluster_public_fqdn_enabled   = false
}

# Enable API Server VNet Integration (ASVNI) using AzAPI
resource "azapi_update_resource" "aks_enable_asvni" {
  type        = "Microsoft.ContainerService/managedClusters@2024-05-01"
  resource_id = azurerm_kubernetes_cluster.aks.id

  body = jsonencode({
    properties = {
      apiServerAccessProfile = {
        enableVnetIntegration = true
        subnetId              = azurerm_subnet.apiserver.id
      }
    }
  })

  depends_on = [azurerm_kubernetes_cluster.aks]
}
```

Notes
- For private clusters, combine ASVNI with private cluster settings and private DNS as per docs.
- If you use strict NSGs, add the ports listed above.
- Converting an existing cluster requires an immediate restart and can change the API server IP.


## Quick validation

- After apply, verify `kubectl` access from an allowed network and confirm nodes reach the API server privately.
- Public access can be toggled (authorized IPs or disabled). For fully private admin, use Private Link with ASVNI as documented.