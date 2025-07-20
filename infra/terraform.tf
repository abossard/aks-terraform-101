# Terraform Configuration
terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.15"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    pkcs12 = {
      source  = "chilicat/pkcs12"
      version = "~> 0.0.7"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Configure the Azure Provider
provider "azurerm" {
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

# Configure Kubernetes Provider with conditional configuration
provider "kubernetes" {
  host                   = try(azurerm_kubernetes_cluster.main.kube_config[0].host, null)
  client_certificate     = try(base64decode(azurerm_kubernetes_cluster.main.kube_config[0].client_certificate), null)
  client_key             = try(base64decode(azurerm_kubernetes_cluster.main.kube_config[0].client_key), null)
  cluster_ca_certificate = try(base64decode(azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate), null)
}

# Configure Helm Provider with conditional configuration
provider "helm" {
  kubernetes {
    host                   = try(azurerm_kubernetes_cluster.main.kube_config[0].host, null)
    client_certificate     = try(base64decode(azurerm_kubernetes_cluster.main.kube_config[0].client_certificate), null)
    client_key             = try(base64decode(azurerm_kubernetes_cluster.main.kube_config[0].client_key), null)
    cluster_ca_certificate = try(base64decode(azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate), null)
  }
}

# Data sources
data "azurerm_client_config" "current" {}