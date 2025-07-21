# Monitoring and Logging Configuration

# Diagnostic Settings for AKS
resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "aks-diagnostics"
  target_resource_id         = azurerm_kubernetes_cluster.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "kube-audit"
  }

  enabled_log {
    category = "kube-audit-admin"
  }

  enabled_log {
    category = "kube-controller-manager"
  }

  enabled_log {
    category = "kube-scheduler"
  }

  enabled_log {
    category = "cluster-autoscaler"
  }

  enabled_log {
    category = "guard"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# Diagnostic Settings for Application Gateway
resource "azurerm_monitor_diagnostic_setting" "app_gateway" {
  name                       = "app-gateway-diagnostics"
  target_resource_id         = azurerm_application_gateway.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  enabled_log {
    category = "ApplicationGatewayPerformanceLog"
  }

  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# Diagnostic Settings for Azure Firewall
resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                       = "firewall-diagnostics"
  target_resource_id         = azurerm_firewall.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "AzureFirewallApplicationRule"
  }

  enabled_log {
    category = "AzureFirewallNetworkRule"
  }

  enabled_log {
    category = "AzureFirewallDnsProxy"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# Diagnostic Settings for Key Vault
resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  name                       = "kv-diagnostics"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_log {
    category = "AzurePolicyEvaluationDetails"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# Diagnostic Settings for Storage Account
resource "azurerm_monitor_diagnostic_setting" "storage" {
  name                       = "storage-diagnostics"
  target_resource_id         = azurerm_storage_account.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_metric {
    category = "Transaction"
  }

  enabled_metric {
    category = "Capacity"
  }
}

# Diagnostic Settings for SQL Database
resource "azurerm_monitor_diagnostic_setting" "sql_database" {
  name                       = "sql-diagnostics"
  target_resource_id         = azurerm_mssql_database.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "SQLInsights"
  }

  enabled_log {
    category = "AutomaticTuning"
  }

  enabled_log {
    category = "QueryStoreRuntimeStatistics"
  }

  enabled_log {
    category = "QueryStoreWaitStatistics"
  }

  enabled_log {
    category = "Errors"
  }

  enabled_log {
    category = "DatabaseWaitStatistics"
  }

  enabled_log {
    category = "Timeouts"
  }

  enabled_log {
    category = "Blocks"
  }

  enabled_log {
    category = "Deadlocks"
  }

  enabled_metric {
    category = "Basic"
  }

  enabled_metric {
    category = "InstanceAndAppAdvanced"
  }

  enabled_metric {
    category = "WorkloadManagement"
  }
}

# Application Insights for application monitoring
resource "azurerm_application_insights" "main" {
  name                = "appi-${var.environment}-${var.project}-${var.location_code}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = local.common_tags
}

# Action Groups for Alerts
resource "azurerm_monitor_action_group" "main" {
  name                = "ag-critical-${var.environment}-${var.project}"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "critical"

  email_receiver {
    name          = "security-team"
    email_address = local.detected_user_email
  }

  tags = local.common_tags
}

# Alert Rules
# AKS Cluster Health Alert
resource "azurerm_monitor_metric_alert" "aks_node_ready" {
  name                = "aks-node-not-ready"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_kubernetes_cluster.main.id]
  description         = "Alert when AKS nodes are not ready"
  severity            = 1

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "kube_node_status_condition"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1

    dimension {
      name     = "condition"
      operator = "Include"
      values   = ["Ready"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }

  tags = local.common_tags
}

# Application Gateway Health Alert
resource "azurerm_monitor_metric_alert" "app_gateway_health" {
  name                = "app-gateway-unhealthy-hosts"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_application_gateway.main.id]
  description         = "Alert when Application Gateway has unhealthy backend hosts"
  severity            = 2

  criteria {
    metric_namespace = "Microsoft.Network/applicationGateways"
    metric_name      = "UnhealthyHostCount"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 0
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }

  tags = local.common_tags
}

# Azure Firewall Threat Alert
resource "azurerm_monitor_metric_alert" "firewall_threats" {
  name                = "firewall-threat-detected"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_firewall.main.id]
  description         = "Alert when Azure Firewall detects threats"
  severity            = 0

  criteria {
    metric_namespace = "Microsoft.Network/azureFirewalls"
    metric_name      = "FirewallHealth"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 100
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }

  tags = local.common_tags
}

# Log Analytics Queries (saved searches)
resource "azurerm_log_analytics_saved_search" "aks_pod_failures" {
  name                       = "AKS Pod Failures"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  category                   = "AKS"
  display_name               = "Failed Pods in AKS"
  query                      = <<-EOT
    KubePodInventory
    | where PodStatus == "Failed"
    | summarize count() by Computer, PodName, Namespace
    | order by count_ desc
  EOT
}

resource "azurerm_log_analytics_saved_search" "app_gateway_errors" {
  name                       = "Application Gateway Errors"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  category                   = "ApplicationGateway"
  display_name               = "Application Gateway 5xx Errors"
  query                      = <<-EOT
    AzureDiagnostics
    | where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayAccessLog"
    | where httpStatus_d >= 500
    | summarize count() by clientIP_s, httpStatus_d, requestUri_s
    | order by count_ desc
  EOT
}

resource "azurerm_log_analytics_saved_search" "firewall_blocked" {
  name                       = "Firewall Blocked Requests"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  category                   = "AzureFirewall"
  display_name               = "Azure Firewall Blocked Requests"
  query                      = <<-EOT
    AzureDiagnostics
    | where ResourceProvider == "MICROSOFT.NETWORK" and Category == "AzureFirewallApplicationRule"
    | where msg_s contains "Deny"
    | summarize count() by SourceIp, Fqdn, Action
    | order by count_ desc
  EOT
}