# SSL Certificate Generation for Demo
# In production, use a proper CA-signed certificate

resource "tls_private_key" "app_gateway" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "wildcard" {
  private_key_pem = tls_private_key.app_gateway.private_key_pem

  subject {
    common_name  = "*.yourdomain.com"  # Wildcard certificate
    organization = "AKS Demo"
  }

  validity_period_hours = 8760
  allowed_uses         = ["key_encipherment", "digital_signature", "server_auth"]
  
  # Subject Alternative Names for multiple domains
  dns_names = [
    "*.yourdomain.com",
    "yourdomain.com",
    "app.yourdomain.com",
    "api.yourdomain.com"
  ]
}

resource "pkcs12_from_pem" "wildcard" {
  cert_pem        = tls_self_signed_cert.wildcard.cert_pem
  private_key_pem = tls_private_key.app_gateway.private_key_pem
  password        = random_password.generated["ssl_cert"].result
}

resource "azurerm_key_vault_secret" "ssl_certificate" {
  name         = "wildcard-ssl-certificate"
  value        = base64encode(pkcs12_from_pem.wildcard.result)
  key_vault_id = azurerm_key_vault.main.id
  content_type = "application/x-pkcs12"
}