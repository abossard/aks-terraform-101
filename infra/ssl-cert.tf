# SSL Certificate Generation for Demo
# In production, use a proper CA-signed certificate

# Generate a private key
resource "tls_private_key" "app_gateway" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Generate a self-signed certificate
resource "tls_self_signed_cert" "app_gateway" {
  private_key_pem = tls_private_key.app_gateway.private_key_pem

  subject {
    common_name  = "aks-demo.local"
    organization = "AKS Demo"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# Create PFX certificate for Application Gateway
resource "pkcs12_from_pem" "app_gateway" {
  cert_pem        = tls_self_signed_cert.app_gateway.cert_pem
  private_key_pem = tls_private_key.app_gateway.private_key_pem
  password        = var.ssl_cert_password != "" ? var.ssl_cert_password : "demo123!"
}

# Store certificate in Key Vault as a secret (workaround for PKCS#12 format issue)
resource "azurerm_key_vault_secret" "ssl_certificate" {
  name         = "ssl-certificate"
  value        = base64encode(pkcs12_from_pem.app_gateway.result)
  key_vault_id = azurerm_key_vault.main.id
  content_type = "application/x-pkcs12"

  # Need explicit dependency since Key Vault is private and needs endpoint ready  
  depends_on = [azurerm_private_endpoint.key_vault]
}