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
    mode                        = "Prevention" # Static mode after firewall removal
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }

  # OWASP Managed Rules
  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"

      # Allow API JSON payloads (common exclusions for APIs)
      rule_group_override {
        rule_group_name = "REQUEST-920-PROTOCOL-ENFORCEMENT"

        rule {
          id      = "920300"
          enabled = false # Request Missing an Accept Header
        }

        rule {
          id      = "920330"
          enabled = false # Empty User Agent Header
        }
      }
    }
  }

}