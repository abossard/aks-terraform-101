# Terraform Configuration
terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
  version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
  version = "~> 3.7"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    pkcs12 = {
      source  = "chilicat/pkcs12"
      version = "~> 0.0.7"
    }
    sqlsso = {
      source  = "jason-johnson/sqlsso"
      version = "1.4.0"
    }
    http = {
      source  = "hashicorp/http"
  version = "~> 3.5"
    }
  }
}

# Configure the Azure Provider
provider "azurerm" {
  # Use Entra ID authentication for storage accounts instead of account keys
  storage_use_azuread = true

  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

}

# Kubernetes and Helm providers removed - deploy K8s resources manually after infrastructure

# Data sources
data "azurerm_client_config" "current" {}

# Detect current public IP for temporary firewall allowances (no auth)
data "http" "myip" {
  url = "https://api.ipify.org?format=text"
}