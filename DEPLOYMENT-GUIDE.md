# AKS Secure Baseline Deployment Guide

This guide will walk you through deploying a production-ready AKS cluster following Microsoft's secure baseline architecture.

## 🏗️ Architecture Overview

**Traffic Flow**: Internet → Application Gateway (WAF) → NGINX Ingress (Internal) → Cilium eBPF → Pods → Internet

**Key Features**:
- ✅ AKS with CNI Overlay + Cilium eBPF data plane
- ✅ Zero Trust networking (single public IP)
- ✅ Simplified egress (no centralized firewall)
- ✅ Private endpoints for all Azure services
- ✅ Workload Identity for secure authentication
- ✅ Application Gateway with WAF protection
- ✅ Comprehensive monitoring and alerting

## 📋 Prerequisites

### 1. Azure CLI and Tools
```bash
# Azure CLI (latest version)
az version

# Terraform (>= 1.0)
terraform version

# kubectl
kubectl version --client

# Helm
helm version
```

### 2. Azure Subscription Access
```bash
# Login to Azure
az login

# Set subscription
az account set --subscription "your-subscription-id"

# Get your subscription ID
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo $ARM_SUBSCRIPTION_ID
```

### 3. Required Azure AD Information
You'll need:
- **SQL Admin Object ID**: Azure AD group for SQL Server administration
- **Security Email**: Email address for alerts and notifications

```bash
# Get your Azure AD tenant ID
az account show --query tenantId -o tsv

# List Azure AD groups (find your SQL admin group)
az ad group list --query "[].{name:displayName, id:id}" -o table

# Get specific group object ID
az ad group show --group "your-sql-admin-group" --query id -o tsv
```

## 🚀 Deployment Steps

### Step 1: Clone and Setup

```bash
cd /Users/abossard/Desktop/projects/aks-terraform-101/infra

# Copy example variables
cp terraform.tfvars.example terraform.tfvars
```

### Step 2: Configure Variables

Edit `terraform.tfvars` with your specific values:

```hcl
# REQUIRED: Update these values
sql_admin_password         = "YourStrongPassword123!"
sql_azuread_admin_object_id = "your-group-object-id"
security_email             = "your-email@company.com"

# Optional: Customize these
environment   = "prod"
project      = "aks101"
location     = "East US"
location_code = "eus"
```

### Step 3: Initialize Terraform

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Review planned changes
terraform plan
```

### Step 4: Deploy Infrastructure

```bash
# Deploy (this will take 15-20 minutes)
terraform apply

# Confirm when prompted
# yes
```

### Step 5: Configure kubectl

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name)

# Verify connection
kubectl get nodes
kubectl get pods --all-namespaces
```

### Step 6: Verify Deployment

```bash
# Check NGINX Ingress
kubectl get svc -n ingress-nginx

# Check Application Gateway backend health
az network application-gateway show-backend-health \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw application_gateway_name)

# Test application access
curl -k https://$(terraform output -raw application_gateway_public_ip)
```

## 🔍 Post-Deployment Verification

### 1. Network Connectivity
```bash
# Verify NGINX Ingress has internal IP
kubectl get svc ingress-nginx-controller -n ingress-nginx

# Check Application Gateway backend health
# Should show "Healthy" status for NGINX backend
```

### 2. Workload Identity
```bash
# Check workload identity pods
kubectl get pods -n aks-app

# Verify secrets are mounted
kubectl exec -n aks-app deployment/sample-app -- ls -la /mnt/secrets-store
```

### 3. Private Endpoints
```bash
# Test Key Vault access from within cluster
kubectl exec -n aks-app deployment/sample-app -- nslookup $(terraform output -raw key_vault_name).vault.azure.net

# Should resolve to private IP (10.240.3.x)
```

### 4. Egress
Egress is provided via the platform load balancer SNAT (no Azure Firewall deployed).

## 🔧 Common Issues and Solutions

### Issue 1: Terraform Apply Fails
**Error**: Resource already exists or permission denied

**Solution**:
```bash
# Check Azure subscription
az account show

# Verify required permissions
az role assignment list --assignee $(az account show --query user.name -o tsv)

# Clean up partial deployment if needed
terraform destroy
```

### Issue 2: AKS Nodes Not Ready
**Error**: Nodes stuck in "NotReady" state

**Solution**:
```bash
# Check node status
kubectl describe nodes

# Check system pods
kubectl get pods -n kube-system

# Restart nodes if needed
az aks nodepool update \
  --resource-group $(terraform output -raw resource_group_name) \
  --cluster-name $(terraform output -raw aks_cluster_name) \
  --name default
```

### Issue 3: Application Gateway Backend Unhealthy
**Error**: Backend shows "Unhealthy" status

**Solution**:
```bash
# Check NGINX Ingress service
kubectl get svc -n ingress-nginx

# Verify internal IP matches Application Gateway backend
terraform output nginx_internal_ip

# Check NSG rules
az network nsg rule list \
  --resource-group $(terraform output -raw resource_group_name) \
  --nsg-name $(terraform output -raw resource_group_name)-nsg-aks-prod-eus-001
```

### Issue 4: Private Endpoint DNS Resolution
**Error**: Services can't resolve private endpoint FQDNs

**Solution**:
```bash
# Check private DNS zones
az network private-dns zone list \
  --resource-group $(terraform output -raw resource_group_name)

# Verify VNet links
az network private-dns link vnet list \
  --resource-group $(terraform output -raw resource_group_name) \
  --zone-name privatelink.vaultcore.azure.net
```

## 📊 Monitoring and Operations

### Access Azure Portal
1. **Log Analytics**: View logs and metrics
2. **Application Insights**: Application performance monitoring
3. **Application Gateway**: WAF logs and metrics

### Key Monitoring Queries
```kql
// Failed pods
KubePodInventory
| where PodStatus == "Failed"
| summarize count() by Computer, PodName, Namespace

// Application Gateway errors
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.NETWORK" 
| where Category == "ApplicationGatewayAccessLog"
| where httpStatus_d >= 400

```

## 🧹 Cleanup

### Complete Teardown
```bash
# Destroy all resources
terraform destroy

# Confirm when prompted
# yes

# Clean up Terraform state
rm -rf .terraform terraform.tfstate*
```

### Selective Cleanup
```bash
# Remove specific resources
terraform state rm azurerm_kubernetes_cluster.main
terraform apply
```

## 🔐 Security Considerations

### Production Recommendations
1. **SSL Certificates**: Replace self-signed certificates with CA-signed ones
2. **Key Vault Access**: Implement proper RBAC policies
3. **SQL Authentication**: Use Azure AD authentication only
4. **Network Policies**: Implement Cilium network policies
5. **Pod Security**: Enable Pod Security Standards
6. **Image Scanning**: Enable container image vulnerability scanning

### Secret Management
```bash
# Store sensitive values in Key Vault
az keyvault secret set \
  --vault-name $(terraform output -raw key_vault_name) \
  --name "db-connection-string" \
  --value "your-connection-string"
```

## 📞 Support

### Troubleshooting Resources
- [AKS Troubleshooting Guide](https://docs.microsoft.com/en-us/azure/aks/troubleshooting)
- [Application Gateway Troubleshooting](https://docs.microsoft.com/en-us/azure/application-gateway/application-gateway-troubleshooting-502)
<!-- Azure Firewall documentation removed -->

### Get Help
```bash
# Check Terraform output
terraform output

# View resource status
terraform show | grep -A 5 "resource_group_name"

# Export configuration for support
terraform show -json > infrastructure-state.json
```

## 🎯 Next Steps

1. **Deploy Your Application**: Replace the sample app with your workload
2. **Configure DNS**: Set up custom domains and SSL certificates
3. **Implement GitOps**: Set up CI/CD pipelines for application deployment
4. **Scale Out**: Add additional node pools for different workload types
5. **Enhance Security**: Implement additional security policies and scanning

---

**🎉 Congratulations!** You now have a production-ready AKS cluster following Microsoft's secure baseline architecture!