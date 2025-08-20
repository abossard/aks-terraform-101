# Auto-Generated Secrets and Passwords
# This file generates secure random passwords and secrets automatically
# Users never need to specify sensitive values

# Generate secure passwords
resource "random_password" "generated" {
  for_each = local.password_configs

  length           = each.value.length
  special          = true
  upper            = true
  lower            = true
  numeric          = true
  min_upper        = each.value.min_upper
  min_lower        = each.value.min_lower
  min_numeric      = each.value.min_numeric
  min_special      = each.value.min_special
  override_special = each.value.override_special
}

# Generate additional secure random strings for naming uniqueness
resource "random_string" "unique_suffix" {
  length  = 6
  special = false
  upper   = false
  lower   = true
  numeric = true
}

# Store generated passwords securely in Key Vault
resource "azurerm_key_vault_secret" "passwords" {
  for_each = local.password_configs

  name         = each.value.secret_name
  value        = random_password.generated[each.key].result
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  depends_on   = [time_sleep.kv_rbac_propagation]
}

# Sensitive outputs for retrieval if needed
output "generated_passwords" {
  description = "Auto-generated passwords"
  value = {
    for k, v in random_password.generated : k => v.result
  }
  sensitive = true
}

output "generated_info" {
  description = "Information about generated values"
  sensitive   = true
  value = {
    unique_suffix   = random_string.unique_suffix.result
    deployment_time = timestamp()
  }
}
