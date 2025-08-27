# Terraform Configuration
terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.6.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.10"
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
  backend "azurerm" {
    resource_group_name  = "rg-else-tf-stg-gwc-001"
    storage_account_name = "stelsetfstggwc001"
    container_name       = "state"
    key                  = "aks-terraform-101/prod.terraform.tfstate"
    subscription_id      = "b503856d-964d-4c51-94a4-f713c1d328fe"
  }
}

# Configure the Azure Provider
provider "azurerm" {
  # Use Entra ID authentication for storage accounts instead of account keys
  storage_use_azuread = true
  subscription_id     = "b503856d-964d-4c51-94a4-f713c1d328fe"
  tenant_id           = "372ee9e0-9ce0-4033-a64a-c07073a91ecd"
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

# AzAPI provider for ARM-level updates (e.g., enabling ASVNI on AKS)
provider "azapi" {}