# Auto-Generated Secrets and Passwords
# This file generates secure random passwords and secrets automatically
# Users never need to specify sensitive values

# Generate SQL Server admin password
resource "random_password" "sql_admin_password" {
  length  = 20
  special = true
  upper   = true
  lower   = true
  numeric = true
  
  # Ensure SQL Server password complexity requirements
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  min_special = 2
  
  # Avoid characters that might cause issues in connection strings
  override_special = "!@#$%&*()-_=+[]{}|;:,.<>?"
}

# Generate SSL certificate password
resource "random_password" "ssl_cert_password" {
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true
  
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
  min_special = 1
}

# Generate additional secure random strings for naming uniqueness
resource "random_string" "unique_suffix" {
  length  = 6
  special = false
  upper   = false
  lower   = true
  numeric = true
}

# Store generated passwords securely in Key Vault (after it's created)
resource "azurerm_key_vault_secret" "sql_admin_password" {
  name         = "sql-admin-password"
  value        = random_password.sql_admin_password.result
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"

  depends_on = [
    azurerm_private_endpoint.key_vault,
    azurerm_role_assignment.current_user_key_vault_admin
  ]
}

resource "azurerm_key_vault_secret" "ssl_cert_password" {
  name         = "ssl-certificate-password"
  value        = random_password.ssl_cert_password.result
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"

  depends_on = [
    azurerm_private_endpoint.key_vault,
    azurerm_role_assignment.current_user_key_vault_admin
  ]
}

# Output the generated values (marked as sensitive)
output "generated_passwords_info" {
  description = "Information about generated passwords (not the actual passwords)"
  sensitive = true
  value = {
    sql_password_length = length(random_password.sql_admin_password.result)
    ssl_password_length = length(random_password.ssl_cert_password.result)
    unique_suffix       = random_string.unique_suffix.result
    deployment_time     = timestamp()
  }
}

# Sensitive outputs for retrieval if needed
output "sql_admin_password" {
  description = "Auto-generated SQL admin password"
  value       = random_password.sql_admin_password.result
  sensitive   = true
}

output "ssl_cert_password" {
  description = "Auto-generated SSL certificate password"
  value       = random_password.ssl_cert_password.result
  sensitive   = true
}
