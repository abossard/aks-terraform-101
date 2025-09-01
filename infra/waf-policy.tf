# WAF Policy for Application Gateway
# Restricts API access to internal sources only

resource "azurerm_web_application_firewall_policy" "main" {
  name                = "waf-policy-${var.environment}-${var.location_code}-001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  # Custom rule: Block API access from external IPs
  custom_rules {
    name      = "RestrictAPIToInternalOnly"
    priority  = 1
    rule_type = "MatchRule"
    action    = "Block"

    # Match API requests by Host header
    match_conditions {
      match_variables {
        variable_name = "RequestHeaders"
        selector      = "Host"
      }
      operator           = "Equal"
      negation_condition = false
      match_values       = ["api.yourdomain.com"]
    }

    # Block if NOT from allowed subnets (public cluster + app gateway)
    match_conditions {
      match_variables {
        variable_name = "RemoteAddr"
      }
      operator           = "IPMatch"
      negation_condition = true # NOT from these IPs = BLOCK
      match_values = [
        var.clusters.public.subnet_cidr, # Public cluster subnet
        local.app_gateway_subnet_cidr,   # App Gateway subnet (health probes)
      ]
    }
  }

  # Allow all other traffic (public app access)
  policy_settings {
    enabled                     = true
    mode                        = var.firewall_enforcement_enabled ? "Prevention" : "Detection"
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }

  # BotManager Managed Rules
  managed_rules {
    managed_rule_set {
      type    = "Microsoft_DefaultRuleSet"  # primary
      version = "2.1"
    }
    managed_rule_set {
      type    = "Microsoft_BotManagerRuleSet"
      version = "1.1"
    }
  }
}