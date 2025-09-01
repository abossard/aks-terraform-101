#!/bin/bash

echo "Setting up Terraform Azure environment variables..."

# Azure Provider Configuration
export ARM_SUBSCRIPTION_ID="b503856d-964d-4c51-94a4-f713c1d328fe"
export ARM_TENANT_ID="372ee9e0-9ce0-4033-a64a-c07073a91ecd"

# Azure Backend Configuration (for remote state)
# Note: These environment variables are used when backend config is empty or partially configured
export ARM_RESOURCE_GROUP_NAME="rg-else-tf-stg-gwc-001"
export ARM_STORAGE_ACCOUNT_NAME="stelsetfstggwc001"
export ARM_CONTAINER_NAME="state"
export ARM_KEY="aks-terraform-101/prod.terraform.tfstate"
export TF_CLI_ARGS_init="-backend-config=storage_account_name=$ARM_STORAGE_ACCOUNT_NAME -backend-config=container_name=$ARM_CONTAINER_NAME -backend-config=resource_group_name=$ARM_RESOURCE_GROUP_NAME -backend-config=key=$ARM_KEY"

echo "✅ Environment variables set successfully!"
echo ""
echo "Current configuration:"
echo "  ARM_SUBSCRIPTION_ID: $ARM_SUBSCRIPTION_ID"
echo "  ARM_TENANT_ID: $ARM_TENANT_ID"
echo "  ARM_RESOURCE_GROUP_NAME: $ARM_RESOURCE_GROUP_NAME"
echo "  ARM_STORAGE_ACCOUNT_NAME: $ARM_STORAGE_ACCOUNT_NAME"
echo "  ARM_CONTAINER_NAME: $ARM_CONTAINER_NAME"
echo "  ARM_KEY: $ARM_KEY"
echo "  TF_CLI_ARGS_init: $TF_CLI_ARGS_init"
echo ""
echo "ℹ️  To use these environment variables:"
echo "1. Source this script: source ./setup-tf-env.sh"
echo "2. Run: terraform init -reconfigure"
echo ""
echo "⚠️  Note: Since you're using storage_use_azuread = true in your provider,"
echo "   you should be authenticated via Azure CLI and don't need ARM_ACCESS_KEY."
echo "   Make sure you're logged in with: az login"