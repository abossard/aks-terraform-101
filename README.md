# AKS Secure Baseline with Terraform

> **Production-ready Azure Kubernetes Service (AKS) cluster with comprehensive security, networking, and monitoring**

[![Architecture](https://img.shields.io/badge/Architecture-Secure%20Baseline-blue)](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/containers/aks/secure-baseline-aks)
[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.0-purple)](https://www.terraform.io/)
[![AKS](https://img.shields.io/badge/AKS-CNI%20Overlay%20%2B%20Cilium-green)](https://docs.microsoft.com/en-us/azure/aks/)
[![Azure](https://img.shields.io/badge/Azure-Latest-orange)](https://azure.microsoft.com/)

## 🏗️ Architecture Overview

This project implements Microsoft's **AKS Secure Baseline** reference architecture using Terraform, featuring:

### **Zero Trust Network Architecture**
```
Internet → App Gateway (WAF) → NGINX Ingress (Internal) → Cilium eBPF → Pods → Azure Firewall (Egress) → Internet
```

### **Key Components**
- 🛡️ **Azure Firewall**: Egress control with FQDN filtering
- 🌐 **Application Gateway**: WAF protection (only public IP)
- 🔒 **Private Endpoints**: All Azure services isolated
- 🚀 **AKS**: CNI Overlay + Cilium eBPF data plane
- 🔑 **Workload Identity**: Secure pod authentication
- 📊 **Comprehensive Monitoring**: Logs, metrics, and alerts

## 🎯 Features

### **Network Security**
- ✅ Single public IP entry point (Application Gateway)
- ✅ Zero direct internet access to AKS cluster
- ✅ Azure Firewall with FQDN-based egress control
- ✅ Private endpoints for all Azure services
- ✅ Network policies with Cilium eBPF

### **Modern AKS Configuration**
- ✅ CNI Overlay networking (2025 latest)
- ✅ Cilium eBPF data plane for high performance
- ✅ Workload Identity for credential-free authentication
- ✅ CSI Secrets Store Driver integration
- ✅ Auto-scaling and availability zones

### **Security & Compliance**
- ✅ WAF protection with OWASP Core Rule Set 3.2
- ✅ Private DNS zones for service discovery
- ✅ Key Vault integration with RBAC
- ✅ SQL Server with Azure AD authentication
- ✅ Network security groups and user-defined routes

### **Monitoring & Operations**
- ✅ Log Analytics and Application Insights
- ✅ Diagnostic settings for all resources
- ✅ Alerts for critical scenarios
- ✅ Performance metrics and dashboards

## 🚀 Quick Start

### Prerequisites
- Azure CLI (latest)
- Terraform >= 1.0
- kubectl and Helm
- Azure subscription with appropriate permissions

### Deploy Infrastructure

```bash
# Clone repository
cd infra

# Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Deploy
terraform init
terraform plan
terraform apply

# Configure kubectl
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name)
```

### Verify Deployment
```bash
# Check cluster status
kubectl get nodes

# Test application access
curl -k https://$(terraform output -raw application_gateway_public_ip)

# View monitoring
az portal browse --resource-group $(terraform output -raw resource_group_name)
```

## 📁 Project Structure

```
├── infra/                          # Terraform infrastructure
│   ├── terraform.tf                # Provider configuration
│   ├── variables.tf                # Input variables
│   ├── locals.tf                   # Local values and naming
│   ├── base-infrastructure.tf      # Resource group, VNet, subnets, NSGs
│   ├── security-layer.tf           # Firewall, Key Vault, private endpoints
│   ├── aks-cluster.tf              # AKS cluster with workload identity
│   ├── ingress-layer.tf            # App Gateway + NGINX Ingress
│   ├── ssl-cert.tf                 # SSL certificate management
│   ├── monitoring.tf               # Logging, metrics, and alerts
│   ├── outputs.tf                  # Output values
│   └── terraform.tfvars.example    # Example configuration
├── DEPLOYMENT-GUIDE.md             # Detailed deployment instructions
├── Infrastructure-Plan.md          # Original architecture specification
└── README.md                       # This file
```

## 🔧 Configuration

### Required Variables
Create `infra/terraform.tfvars` with these values:

```hcl
# Required
sql_admin_password         = "YourStrongPassword123!"
sql_azuread_admin_object_id = "your-azure-ad-group-object-id"
security_email             = "security@yourcompany.com"

# Optional customization
environment   = "prod"
project      = "aks101"
location     = "East US"
node_vm_size = "Standard_D4s_v3"
```

### Network Configuration
```hcl
vnet_address_space = "10.240.0.0/16"    # VNet CIDR
pod_cidr          = "192.168.0.0/16"    # Pod overlay network
service_cidr      = "172.16.0.0/16"     # Kubernetes services
```

## 🏢 Architecture Details

### **Network Layout**
- **VNet**: `10.240.0.0/16`
  - **AKS Subnet**: `10.240.0.0/24` (nodes)
  - **App Gateway Subnet**: `10.240.1.0/24`
  - **Firewall Subnet**: `10.240.2.0/24`
  - **Private Endpoints**: `10.240.3.0/24`

### **Traffic Flow**
1. **Inbound**: Internet → App Gateway (WAF) → NGINX Ingress → Pods
2. **Outbound**: Pods → Azure Firewall → Internet (FQDN filtered)
3. **Internal**: Pod-to-pod via Cilium eBPF

### **Security Zones**
- **Public Zone**: Application Gateway only
- **Private Zone**: All other resources
- **Restricted Zone**: Private endpoints subnet

## 📊 Monitoring

### **Built-in Dashboards**
- AKS cluster health and performance
- Application Gateway metrics and WAF logs
- Azure Firewall traffic analysis
- Application performance monitoring

### **Key Alerts**
- Node not ready conditions
- Application Gateway backend health
- Firewall threat detection
- Resource utilization thresholds

### **Log Analytics Queries**
```kql
// View failed pods
KubePodInventory
| where PodStatus == "Failed"
| summarize count() by Namespace, PodName

// Application Gateway errors
AzureDiagnostics
| where Category == "ApplicationGatewayAccessLog"
| where httpStatus_d >= 400
```

## 🔐 Security Features

### **Network Security**
- Zero Trust architecture
- WAF with OWASP protection
- Network segmentation
- Private service connectivity

### **Identity & Access**
- Workload Identity federation
- Azure RBAC integration
- Key Vault secret management
- Service account automation

### **Compliance**
- Microsoft CAF naming conventions
- Security monitoring and alerting
- Audit logging enabled
- Vulnerability scanning ready

## 🛠️ Operations

### **Scaling**
```bash
# Scale node pool
az aks nodepool scale \
  --resource-group $(terraform output -raw resource_group_name) \
  --cluster-name $(terraform output -raw aks_cluster_name) \
  --name default --node-count 5

# Add new node pool
az aks nodepool add \
  --resource-group $(terraform output -raw resource_group_name) \
  --cluster-name $(terraform output -raw aks_cluster_name) \
  --name gpu --node-count 2 --node-vm-size Standard_NC6s_v3
```

### **Updates**
```bash
# Check available versions
az aks get-versions --location "East US"

# Upgrade cluster
az aks upgrade \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name) \
  --kubernetes-version 1.29.0
```

### **Troubleshooting**
```bash
# View cluster status
kubectl describe nodes

# Check system pods
kubectl get pods -n kube-system

# Application Gateway health
az network application-gateway show-backend-health \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw application_gateway_name)
```

## 📈 Cost Optimization

### **Resource Sizing**
- **Node VMs**: Start with Standard_D4s_v3, scale as needed
- **App Gateway**: WAF_v2 with autoscaling (1-10 instances)
- **Firewall**: Standard tier for basic scenarios
- **SQL Database**: S1 tier for development, scale for production

### **Cost Management**
- Enable cluster autoscaler (min: 1, max: 10)
- Use spot instances for dev/test workloads
- Schedule clusters for non-production environments
- Monitor costs with Azure Cost Management

## 🌟 Advanced Features

### **GitOps Integration**
```bash
# Install Flux v2
kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml

# Configure Git repository
flux bootstrap github \
  --owner=your-org \
  --repository=your-repo \
  --branch=main \
  --path=./clusters/production
```

### **Service Mesh**
```bash
# Install Istio (optional)
curl -L https://istio.io/downloadIstio | sh -
istioctl install --set values.defaultRevision=default
```

### **Policy Enforcement**
```bash
# Install Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request

### **Development Guidelines**
- Follow Terraform best practices
- Update documentation for any changes
- Test with multiple Azure regions
- Ensure backward compatibility

## 📚 Resources

### **Documentation**
- [AKS Secure Baseline Architecture](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/containers/aks/secure-baseline-aks)
- [Azure CNI Overlay Documentation](https://docs.microsoft.com/en-us/azure/aks/concepts-network#azure-cni-overlay-networking)
- [Cilium Documentation](https://cilium.io/)
- [Azure Workload Identity](https://docs.microsoft.com/en-us/azure/aks/workload-identity-overview)

### **Support**
- [Deployment Guide](./DEPLOYMENT-GUIDE.md) - Step-by-step instructions
- [Infrastructure Plan](./Infrastructure-Plan.md) - Original architecture specification
- [Azure AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This configuration is provided as-is for educational and reference purposes. Please review and test thoroughly before using in production environments. Ensure compliance with your organization's security and operational requirements.

---

**🎉 Ready to deploy secure, scalable AKS infrastructure? Follow the [Deployment Guide](./DEPLOYMENT-GUIDE.md) to get started!**