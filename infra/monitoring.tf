# Application Insights for application monitoring
resource "azurerm_application_insights" "main" {
  name                = "appi-${var.environment}-${var.project}-${var.location_code}-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = local.common_tags
}