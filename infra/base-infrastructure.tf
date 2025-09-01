# Base Infrastructure Layer
# Resource Group, VNet, Subnets, NSGs

# Random suffix for uniqueness is now in secrets.tf

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.common_tags
  lifecycle {
    precondition {
      condition     = length(local.resource_group_name) <= 90
      error_message = "Resource group name exceeds 90 character limit."
    }
  }
}

# Shared SQL Resource Group (single RG for all SQL assets)
resource "azurerm_resource_group" "sql_shared" {
  name     = local.sql_shared_resource_group_name
  location = var.location
  tags     = local.common_tags
}

# Log Analytics Workspace (needed early for monitoring)
resource "azurerm_log_analytics_workspace" "main" {
  name                = local.log_analytics_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
  depends_on          = [azurerm_resource_group.main]
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = local.vnet_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.vnet_address_space]
  tags                = local.common_tags
  depends_on          = [azurerm_resource_group.main]
}

# AKS Cluster Subnets
resource "azurerm_subnet" "clusters" {
  for_each = var.clusters

  name                 = local.cluster_configs[each.key].subnet_name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [each.value.subnet_cidr]

  # Enable private endpoint policies  
  private_endpoint_network_policies = "Enabled"
  depends_on                        = [azurerm_virtual_network.main]
}

# Application Gateway Subnet
resource "azurerm_subnet" "app_gateway" {
  name                 = local.app_gateway_subnet_name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.app_gateway_subnet_cidr]

  # Application Gateway requires dedicated subnet
  private_endpoint_network_policies = "Enabled"
  depends_on                        = [azurerm_virtual_network.main]
}

# Azure Firewall Subnet (fixed name required)
# resource "azurerm_subnet" "firewall" {
#   name                 = local.firewall_subnet_name
#   resource_group_name  = azurerm_resource_group.main.name
#   virtual_network_name = azurerm_virtual_network.main.name
#   address_prefixes     = [local.firewall_subnet_cidr]

#   # Azure Firewall requires specific configuration
#   private_endpoint_network_policies = "Enabled"
#   depends_on                        = [azurerm_virtual_network.main]
# }

# Private Endpoints Subnet
resource "azurerm_subnet" "private_endpoints" {
  name                 = local.private_endpoints_subnet_name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.pe_subnet_cidr]

  # Disable private endpoint network policies
  private_endpoint_network_policies = "Disabled"
  depends_on                        = [azurerm_virtual_network.main]
}

# API Server subnets per cluster (ASVNI)
resource "azurerm_subnet" "apiserver" {
  for_each = var.enable_api_server_vnet_integration ? var.clusters : {}

  name                 = local.cluster_configs[each.key].apiserver_subnet_name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.cluster_configs[each.key].apiserver_cidr]

  # Delegate to AKS managedClusters (BYO VNet requirement for ASVNI)
  delegation {
    name = "aks-managedclusters"
    service_delegation {
      name = "Microsoft.ContainerService/managedClusters"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        # "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        # "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"
      ]
    }
  }
  depends_on = [azurerm_virtual_network.main]
}

# Network Security Groups for AKS Clusters
resource "azurerm_network_security_group" "clusters" {
  for_each = var.clusters

  name                = local.cluster_configs[each.key].nsg_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  # Allow inbound from Application Gateway
  security_rule {
    name                       = "AllowAppGatewayInbound"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = local.app_gateway_subnet_cidr
    destination_address_prefix = each.value.subnet_cidr
  }

  dynamic "security_rule" {
    for_each = { for k, v in local.common_nsg_rules : k => v if v.direction == "Inbound" && k == "allow_vnet_inbound" }
    content {
      name                       = "AllowVnetInbound"
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }

  dynamic "security_rule" {
    for_each = { for k, v in local.common_nsg_rules : k => v if v.direction == "Outbound" }
    content {
      name                       = security_rule.key == "allow_internet_outbound" ? "AllowInternetOutbound" : "AllowVnetOutbound"
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }
  depends_on = [azurerm_resource_group.main]
}

# Network Security Group for Application Gateway Subnet
resource "azurerm_network_security_group" "app_gateway" {
  name                = local.app_gateway_nsg_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  # Allow inbound HTTP/HTTPS from internet
  security_rule {
    name                       = "AllowHttpsInbound"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # Allow inbound from Gateway Manager (required for App Gateway)
  security_rule {
    name                       = "AllowGatewayManager"
    priority                   = 1100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  # Allow outbound to AKS subnet
  security_rule {
    name                       = "AllowAksOutbound"
    priority                   = 1000
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "*"
    destination_address_prefix = var.vnet_address_space # VNet address space
  }

  dynamic "security_rule" {
    for_each = { for k, v in local.common_nsg_rules : k => v if v.direction == "Outbound" && k == "allow_internet_outbound" }
    content {
      name                       = "AllowInternetOutbound"
      priority                   = 1100
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }
  depends_on = [azurerm_resource_group.main]
}

# Network Security Group for Private Endpoints Subnet
resource "azurerm_network_security_group" "private_endpoints" {
  name                = local.pe_nsg_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  # Allow inbound from VNet
  security_rule {
    name                       = "AllowVnetInbound"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "1433"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Deny all other inbound
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  depends_on = [azurerm_resource_group.main]
}

# Associate NSGs with Cluster Subnets
resource "azurerm_subnet_network_security_group_association" "clusters" {
  for_each = var.clusters

  subnet_id                 = azurerm_subnet.clusters[each.key].id
  network_security_group_id = azurerm_network_security_group.clusters[each.key].id
  depends_on                = [azurerm_subnet.clusters, azurerm_network_security_group.clusters]
}

resource "azurerm_subnet_network_security_group_association" "app_gateway" {
  subnet_id                 = azurerm_subnet.app_gateway.id
  network_security_group_id = azurerm_network_security_group.app_gateway.id
  depends_on                = [azurerm_subnet.app_gateway, azurerm_network_security_group.app_gateway]
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_endpoints.id
  depends_on                = [azurerm_subnet.private_endpoints, azurerm_network_security_group.private_endpoints]
}

resource "azurerm_virtual_network_peering" "netpeer" {
  count = local.vnet_peering_enabled ? 1 : 0

  allow_forwarded_traffic                = true
  allow_gateway_transit                  = var.hub_vnet_config.allow_gateway_transit
  allow_virtual_network_access           = true
  local_subnet_names                     = []
  name                                   = local.vnet_peering_name
  only_ipv6_peering_enabled              = false
  peer_complete_virtual_networks_enabled = true
  remote_subnet_names                    = []
  remote_virtual_network_id              = local.hub_vnet_resource_id
  resource_group_name                    = azurerm_resource_group.main.name
  use_remote_gateways                    = var.hub_vnet_config.use_remote_gateways
  virtual_network_name                   = azurerm_virtual_network.main.name
  depends_on = [
    azurerm_virtual_network.main,
  ]
}