

resource "azurerm_web_application_firewall_policy" "app2" {
  name                = "waf-policy-${var.environment}-${var.location_code}-app2-001"
  resource_group_name = azurerm_resource_group.app["app2"].name
  location            = azurerm_resource_group.app["app2"].location

  # Custom rule: Block API access from external IPs
    # Allow all other traffic (public app access)
  policy_settings {
    enabled                     = true
    mode                        = var.firewall_enforcement_enabled ? "Prevention" : "Detection"
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }

  # OWASP Managed Rules
  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
}