# Let's Encrypt automation with Key Vault Acmebot and Azure Application Gateway

This guide shows how to automate issuance and renewal of TLS certificates from Let's Encrypt using Key Vault Acmebot and consume them from Azure Application Gateway (v2) via Azure Key Vault. It also describes the minimal Terraform changes to switch the gateway from a locally-generated PFX to a Key Vault secret reference.

> Repository used in this guide: Key Vault Acmebot (open source)
> - GitHub: https://github.com/shibayan/keyvault-acmebot
> - Summary: An Azure Functions app that requests/renews ACME certificates and stores them in Azure Key Vault. Works with App Gateway, App Service, Container Apps, Front Door, CDN, etc.

## What you'll build
- Automatic Let's Encrypt certificate issuance/renewal using DNS-01 validation (recommended: Azure DNS)
- Certificates stored as Key Vault secrets (PFX) with rolling versions
- Application Gateway v2 bound to a Key Vault secret via managed identity
- Automatic certificate rotation on the gateway when Key Vault secret version changes

## Prerequisites
- Azure subscription + permissions to deploy resources, assign roles
- A resource group and Key Vault (this repo already creates `azurerm_key_vault.main`)
- Application Gateway v2 with a user-assigned managed identity (this repo already creates one)
- Public DNS zone for your domain (ideally hosted in Azure DNS) with control over records
- Outbound internet access from the Acmebot function app (default) to reach Let's Encrypt and DNS APIs

Important notes about Key Vault + App Gateway:
- App Gateway fetches certs from the Key Vault public endpoint. Private endpoints for Key Vault are not supported for AGW certificate retrieval. Keep public network access enabled on Key Vault (you can still restrict via firewall rules).
- The gateway's managed identity must have read access to secrets in the Key Vault (RBAC role: "Key Vault Secrets User"). This repo already assigns it in `infra/ingress-layer.tf`.

## Step 1 — Deploy Key Vault Acmebot
Key Vault Acmebot offers a portal-driven deployment (Deploy to Azure) that provisions:
- Function App (consumption or premium) with system-assigned managed identity
- Storage account and Application Insights (or Azure Monitor Logs)
- Optional Firewall configs

Follow the instructions in the Acmebot README to deploy. You'll configure:
- Target Key Vault (this repo's `azurerm_key_vault.main`)
- ACME directory: Let's Encrypt production or staging
- DNS provider: Azure DNS is the simplest (DNS-01)

Links:
- https://github.com/shibayan/keyvault-acmebot

## Step 2 — Grant permissions for DNS-01 and Key Vault
- For DNS-01 with Azure DNS, assign the Acmebot Function App's managed identity the role "DNS Zone Contributor" on your DNS zone (or zone resource group).
- Grant the Acmebot Function App managed identity write access to the Key Vault to store certificates/secrets. Minimal RBAC (pick one based on your org standard):
  - Key Vault Secrets Officer (write secrets), or
  - Key Vault Certificates Officer (if using KV Certificate objects), or
  - Key Vault Administrator (broad; not least-privilege).

This repo already grants the Application Gateway user-assigned identity read access to KV secrets:
- `infra/ingress-layer.tf`: `azurerm_role_assignment.app_gateway_key_vault` with role `Key Vault Secrets User`

## Step 3 — Request certificates with Acmebot
Once deployed, use the Acmebot UI (Functions HTTP endpoint) to issue certs:
- Choose domain(s) (wildcard recommended for `*.yourdomain.com` + root if needed)
- Select DNS provider (Azure DNS) and authorize
- Target storage: Azure Key Vault
- Secret naming convention example: `wildcard-yourdomain-com`

Acmebot will:
- Create DNS-01 TXT records under `_acme-challenge`
- Request and validate the certificate
- Store as a PFX secret in your Key Vault, e.g. `wildcard-yourdomain-com` with a versioned secret ID
- Auto-renew before expiry and rotate the secret version

## Step 4 — Terraform changes in this repo
Currently, the gateway uses a self-signed certificate packaged into a PFX and embedded in the resource:
- `infra/ssl-cert.tf` generates the key/cert and stores a copy into Key Vault as a demo
- `infra/ingress-layer.tf` attaches the cert using the `ssl_certificate { data/password }` block

To switch to Key Vault + Acmebot managed certs:

1) Reference an existing Key Vault secret (created by Acmebot) using a data source.

Create a data source (example):
- File: `infra/ingress-layer.tf` (top-level or a new file, your choice)

```
# Reads an existing PFX secret stored by Acmebot
# Adjust the `name` to the secret you created (e.g., wildcard-yourdomain-com)
data "azurerm_key_vault_secret" "appgw_cert" {
  name         = var.appgw_cert_secret_name   # e.g. "wildcard-yourdomain-com"
  key_vault_id = azurerm_key_vault.main.id
}
```

Add a variable for the secret name:
- File: `infra/variables.tf`

```
variable "appgw_cert_secret_name" {
  description = "Name of the Key Vault secret containing the PFX for Application Gateway"
  type        = string
}
```

Set the value in `infra/terraform.tfvars`:

```
appgw_cert_secret_name = "wildcard-yourdomain-com"
```

2) Update the Application Gateway SSL certificate block to use a Key Vault reference.

Replace the existing `ssl_certificate` block in `azurerm_application_gateway.main` with:

```
ssl_certificate {
  name                 = "wildcard-ssl-cert"
  key_vault_secret_id  = data.azurerm_key_vault_secret.appgw_cert.id
}
```

Notes:
- `key_vault_secret_id` must be a Key Vault secret resource ID (not the secret value). The gateway reads the secret when provisioning and on future rotations.
- Do not set `data/password` when using `key_vault_secret_id`.

3) (Optional but recommended) Remove the demo self-signed certificate resources.
- You can delete or conditionally disable the following in `infra/ssl-cert.tf`:
  - `tls_private_key.app_gateway`
  - `tls_self_signed_cert.wildcard`
  - `pkcs12_from_pem.wildcard`
  - `azurerm_key_vault_secret.ssl_certificate` (demo secret)

If you prefer to keep them for local testing, guard with a variable (e.g., `var.use_demo_cert`) and `count` or `for_each` to avoid conflicts.

4) Ensure the Application Gateway identity is present and authorized (already in repo).
- `azurerm_user_assigned_identity.app_gateway` exists
- `azurerm_role_assignment.app_gateway_key_vault` grants `Key Vault Secrets User` at the vault scope

5) Key Vault networking
- Leave `public_network_access_enabled = true` for Key Vault so App Gateway can fetch the secret.
- You may keep a private endpoint for other consumers, but do not disable public access for the vault.
- Optionally restrict the KV firewall (network ACLs) while verifying App Gateway can still access the public endpoint.

## Step 5 — Plan and apply
After you've created the Acmebot secret in Key Vault and updated Terraform:

- Validate and plan
- Apply changes

The Application Gateway should pick up the certificate by referencing the Key Vault secret ID. On Acmebot renewal events, the secret version will roll; Application Gateway v2 will auto-rotate to the newest version.

## Troubleshooting
- Certificate not found: Confirm the secret name in `terraform.tfvars` matches the actual Key Vault secret.
- Access denied reading secret: Verify the gateway's managed identity has `Key Vault Secrets User` on the Key Vault and that Key Vault public access is enabled.
- DNS-01 validation fails: Ensure the Function app identity has `DNS Zone Contributor` on your DNS zone and that TXT records are created under `_acme-challenge`.
- Still serving old cert: Secret rotation can take a little time to reflect; check the App Gateway health and the Key Vault secret version. Re-apply if you changed the secret name.

## References
- Key Vault Acmebot: https://github.com/shibayan/keyvault-acmebot
- App Gateway + Key Vault SSL certs: https://learn.microsoft.com/azure/application-gateway/key-vault-certs
- Azure DNS: https://learn.microsoft.com/azure/dns/dns-overview
- Let's Encrypt ACME: https://letsencrypt.org/how-it-works/

---

If you want, I can implement the Terraform data source and listener changes for you in `infra/ingress-layer.tf` and add the variable stub to `infra/variables.tf`.