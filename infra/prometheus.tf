# Azure Managed Prometheus Configuration
# Pure azurerm provider implementation

# Azure Monitor Workspace for Prometheus
resource "azurerm_monitor_workspace" "prometheus" {
  name                = "amw-${var.environment}-${var.project}-${var.location_code}-001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.common_tags
}

# Data Collection Endpoint
resource "azurerm_monitor_data_collection_endpoint" "prometheus" {
  name                = "dce-${var.environment}-${var.project}-${var.location_code}-001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  kind                = "Linux"
  tags                = local.common_tags
}

# Data Collection Rule for Prometheus
resource "azurerm_monitor_data_collection_rule" "prometheus" {
  name                        = "dcr-${var.environment}-${var.project}-${var.location_code}-001"
  resource_group_name         = azurerm_resource_group.main.name
  location                    = azurerm_resource_group.main.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.prometheus.id
  kind                        = "Linux"

  destinations {
    monitor_account {
      monitor_account_id = azurerm_monitor_workspace.prometheus.id
      name               = "MonitoringAccount1"
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["MonitoringAccount1"]
  }

  data_sources {
    prometheus_forwarder {
      streams = ["Microsoft-PrometheusMetrics"]
      name    = "PrometheusDataSource"
    }
  }

  tags = local.common_tags
}

# Associate DCR with AKS Clusters
resource "azurerm_monitor_data_collection_rule_association" "prometheus" {
  for_each = var.clusters
  
  name                    = "dcra-${var.environment}-${var.project}-${each.value.name_suffix}-${var.location_code}-001"
  target_resource_id      = azurerm_kubernetes_cluster.main[each.key].id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.prometheus.id
}