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

## 🔐 Core Security Principles

This implementation follows Microsoft's **AKS Secure Baseline** architecture, built on these foundational security principles:

### **Zero Trust Network Architecture**
- **Principle**: "Never trust, always verify" - no implicit trust based on network location
- **Implementation**: Single public entry point through Application Gateway, all other resources private
- **Microsoft Guidance**: [Zero Trust security model](https://docs.microsoft.com/en-us/security/zero-trust/)

### **Defense in Depth**
- **Principle**: Multiple layers of security controls to protect against threats
- **Implementation**: WAF → Network Policies → Pod Security → RBAC → Private Endpoints
- **Microsoft Guidance**: [Defense in depth strategy](https://docs.microsoft.com/en-us/azure/architecture/guide/security/defense-in-depth)

### **Principle of Least Privilege**
- **Principle**: Grant minimum permissions necessary for operation
- **Implementation**: Workload Identity, Azure RBAC, Network Security Groups, Firewall rules
- **Microsoft Guidance**: [Identity and access management best practices](https://docs.microsoft.com/en-us/azure/security/fundamentals/identity-management-best-practices)

### **Network Segmentation**
- **Principle**: Isolate workloads and limit blast radius of security incidents
- **Implementation**: Separate subnets, NSGs, private endpoints, user-defined routing
- **Microsoft Guidance**: [Network security best practices](https://docs.microsoft.com/en-us/azure/security/fundamentals/network-best-practices)

### **Credential-Free Authentication**
- **Principle**: Eliminate stored secrets and reduce credential-based attacks
- **Implementation**: Workload Identity federation with Azure AD, CSI Secret Store integration
- **Microsoft Guidance**: [Workload identity best practices](https://docs.microsoft.com/en-us/azure/aks/workload-identity-best-practices)

### **Continuous Monitoring & Audit**
- **Principle**: Comprehensive visibility and audit trail for security events
- **Implementation**: Log Analytics, diagnostic settings, alerts, Azure Security Center integration
- **Microsoft Guidance**: [Security monitoring and audit](https://docs.microsoft.com/en-us/azure/security/fundamentals/log-audit)

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

## 🚀 Deployment Guide

### Prerequisites

**Required Tools:**
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (latest version)
- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/) for cluster management
- [Helm](https://helm.sh/docs/intro/install/) for package management

**Azure Requirements:**
- Azure subscription with Owner or Contributor + User Access Administrator roles
- Azure AD permissions to create service principals and assign roles
- Sufficient quota for the resources (especially compute cores)

### Step-by-Step Deployment

#### 1. Prepare Environment
```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription "your-subscription-id"

# Verify permissions
az role assignment list --assignee $(az account show --query user.name -o tsv)
```

#### 2. Get Required Azure AD Information
```bash
# Get your tenant ID
az account show --query tenantId -o tsv

# Create or find SQL admin group (recommended)
az ad group create \
  --display-name "AKS-SQL-Admins" \
  --mail-nickname "aks-sql-admins"

# Get the group object ID for terraform.tfvars
az ad group show \
  --group "AKS-SQL-Admins" \
  --query id -o tsv
```

#### 3. Configure Infrastructure
```bash
# Clone and navigate to infrastructure
cd infra

# Copy and customize variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values:
# - sql_admin_password: Strong password for SQL Server
# - sql_azuread_admin_object_id: Object ID from step 2
# - security_email: Your email for security alerts
```

#### 4. Deploy Infrastructure
```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Review deployment plan (takes 2-3 minutes)
terraform plan

# Deploy infrastructure (takes 15-20 minutes)
terraform apply
# Type "yes" when prompted
```

#### 5. Configure Cluster Access
```bash
# Configure kubectl
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name)

# Verify cluster connectivity
kubectl get nodes
kubectl get pods --all-namespaces
```

### Deployment Verification

#### Infrastructure Health Checks
```bash
# 1. Verify NGINX Ingress is running with internal IP
kubectl get svc ingress-nginx-controller -n ingress-nginx

# 2. Check Application Gateway backend health
az network application-gateway show-backend-health \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw application_gateway_name)

# 3. Test workload identity integration
kubectl get pods -n aks-app
kubectl describe pod -n aks-app -l app=sample-app

# 4. Verify private endpoint DNS resolution
kubectl run test-pod --image=busybox:1.35 --rm -it --restart=Never \
  -- nslookup $(terraform output -raw key_vault_name).vault.azure.net
```

#### Security Validation
```bash
# 1. Confirm egress is routed through firewall
kubectl run test-egress --image=curlimages/curl --rm -it --restart=Never \
  -- curl -s https://httpbin.org/ip

# 2. Check firewall logs for the connection
az monitor log-analytics query \
  --workspace $(terraform output -raw log_analytics_workspace_id) \
  --analytics-query "AzureDiagnostics | where ResourceProvider == 'MICROSOFT.NETWORK' and Category == 'AzureFirewallNetworkRule' | top 10 by TimeGenerated desc"

# 3. Test WAF protection
curl -H "User-Agent: BadBot" https://$(terraform output -raw application_gateway_public_ip)
```

### Quick Start (Minimal Setup)
For a basic deployment with default settings:

```bash
# Quick deployment with minimal configuration
cd infra
cp terraform.tfvars.example terraform.tfvars

# Edit only the required values:
# - sql_admin_password
# - sql_azuread_admin_object_id  
# - security_email

terraform init && terraform apply -auto-approve
```

### Troubleshooting Common Issues

See the [detailed deployment guide](./DEPLOYMENT-GUIDE.md) for comprehensive troubleshooting steps.

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

## 📖 Microsoft Best Practices Implementation

This infrastructure implements specific Microsoft Azure best practices and recommendations:

### **AKS Secure Baseline Architecture**
- **Microsoft Guidance**: [AKS Secure Baseline Reference Architecture](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/containers/aks/secure-baseline-aks)
- **Implementation**: Complete architectural pattern with private cluster, egress control, and workload identity
- **Components**: Application Gateway + WAF, Azure Firewall, Private Endpoints, CNI Overlay networking

### **Container Networking Best Practices**
- **Microsoft Guidance**: [AKS networking concepts and best practices](https://docs.microsoft.com/en-us/azure/aks/concepts-network)
- **Implementation**: 
  - CNI Overlay networking for IP efficiency: [CNI Overlay documentation](https://docs.microsoft.com/en-us/azure/aks/concepts-network#azure-cni-overlay-networking)
  - Cilium eBPF data plane for performance: [Cilium dataplane](https://docs.microsoft.com/en-us/azure/aks/azure-cni-overlay?tabs=kubectl#cilium-data-plane)
  - User-defined routing through Azure Firewall: [Egress traffic control](https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic)

### **Identity and Access Management**
- **Microsoft Guidance**: [AKS identity and access best practices](https://docs.microsoft.com/en-us/azure/aks/best-practices-identity)
- **Implementation**:
  - Workload Identity federation: [Workload Identity overview](https://docs.microsoft.com/en-us/azure/aks/workload-identity-overview)
  - Azure RBAC integration: [Azure RBAC for AKS](https://docs.microsoft.com/en-us/azure/aks/manage-azure-rbac)
  - CSI Secret Store integration: [Secrets Store CSI driver](https://docs.microsoft.com/en-us/azure/aks/csi-secrets-store-driver)

### **Network Security Best Practices**
- **Microsoft Guidance**: [AKS network security best practices](https://docs.microsoft.com/en-us/azure/aks/best-practices-network)
- **Implementation**:
  - Private cluster with no public endpoint exposure
  - Network policies with Cilium: [Network policies](https://docs.microsoft.com/en-us/azure/aks/use-network-policies)
  - Application Gateway with WAF: [Application Gateway with AKS](https://docs.microsoft.com/en-us/azure/application-gateway/ingress-controller-overview)

### **Security and Compliance**
- **Microsoft Guidance**: [AKS security best practices](https://docs.microsoft.com/en-us/azure/aks/best-practices-security)
- **Implementation**:
  - Pod Security Standards enforcement
  - Private endpoints for all Azure services: [Private endpoints](https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-overview)
  - Diagnostic logging and monitoring: [AKS monitoring](https://docs.microsoft.com/en-us/azure/aks/monitor-aks)

### **Cloud Adoption Framework (CAF)**
- **Microsoft Guidance**: [CAF for Azure Kubernetes Service](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/aks/)
- **Implementation**:
  - CAF naming conventions: [Resource naming](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)
  - Resource organization and tagging: [Resource organization](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/organize-subscriptions)
  - Landing zone principles: [AKS landing zone](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/aks/aks-start-here)

### **Operations and Monitoring**
- **Microsoft Guidance**: [AKS monitoring best practices](https://docs.microsoft.com/en-us/azure/aks/best-practices-monitoring)
- **Implementation**:
  - Container insights integration: [Container insights](https://docs.microsoft.com/en-us/azure/azure-monitor/containers/container-insights-overview)
  - Log Analytics workspace configuration: [Log Analytics](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/log-analytics-workspace-overview)
  - Application insights for workload monitoring: [Application Insights](https://docs.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview)

### **Performance and Scalability**
- **Microsoft Guidance**: [AKS performance best practices](https://docs.microsoft.com/en-us/azure/aks/best-practices-performance-scale)
- **Implementation**:
  - Cluster autoscaler configuration: [Cluster autoscaler](https://docs.microsoft.com/en-us/azure/aks/cluster-autoscaler)
  - Node pool optimization: [Node pools](https://docs.microsoft.com/en-us/azure/aks/use-multiple-node-pools)
  - Resource quotas and limits: [Resource management](https://docs.microsoft.com/en-us/azure/aks/operator-best-practices-scheduler)

## 📚 Resources

## 📚 Resources

### **Microsoft Official Documentation**

#### **Architecture & Design**
- [AKS Secure Baseline Architecture](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/containers/aks/secure-baseline-aks) - Reference architecture implemented by this project
- [AKS Landing Zone Accelerator](https://github.com/Azure/AKS-Landing-Zone-Accelerator) - Microsoft's official implementation guide
- [Cloud Adoption Framework for AKS](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/aks/) - Enterprise AKS adoption guidance

#### **Networking & Security**
- [Azure CNI Overlay Documentation](https://docs.microsoft.com/en-us/azure/aks/concepts-network#azure-cni-overlay-networking) - Modern AKS networking
- [Cilium Documentation](https://cilium.io/) - eBPF-based networking and security
- [Azure Workload Identity](https://docs.microsoft.com/en-us/azure/aks/workload-identity-overview) - Credential-free authentication
- [AKS egress traffic control](https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic) - Azure Firewall integration

#### **Best Practices Guides**
- [AKS security best practices](https://docs.microsoft.com/en-us/azure/aks/best-practices-security) - Comprehensive security guidance
- [AKS network security best practices](https://docs.microsoft.com/en-us/azure/aks/best-practices-network) - Network security implementation
- [AKS identity and access best practices](https://docs.microsoft.com/en-us/azure/aks/best-practices-identity) - Identity management patterns
- [AKS monitoring best practices](https://docs.microsoft.com/en-us/azure/aks/best-practices-monitoring) - Observability patterns

#### **Operations & Troubleshooting**
- [AKS Troubleshooting Guide](https://docs.microsoft.com/en-us/azure/aks/troubleshooting) - Common issues and solutions
- [Application Gateway Troubleshooting](https://docs.microsoft.com/en-us/azure/application-gateway/application-gateway-troubleshooting-502) - Gateway-specific issues
- [Azure Firewall Documentation](https://docs.microsoft.com/en-us/azure/firewall/) - Firewall configuration and troubleshooting

### **Project Documentation**
- [Deployment Guide](./DEPLOYMENT-GUIDE.md) - Step-by-step deployment instructions
- [Infrastructure Plan](./Infrastructure-Plan.md) - Detailed architecture specification  
- [Microsoft CAF Naming Conventions](./microsoft-caf-naming-conventions.md) - Resource naming standards
- [Workload Identity Integration](./aks-workload-identity-csi-integration.md) - Identity configuration guide
- [Application Gateway Integration](./application-gateway-aks-nginx-integration.md) - Ingress setup guide
- [Azure Firewall Configuration](./azure-firewall-aks-egress.md) - Egress control setup
- [Private Endpoints Configuration](./azure-private-endpoints-configuration.md) - Private connectivity guide

### **Additional Resources**
- [Azure AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/) - Complete AKS documentation
- [Kubernetes Official Documentation](https://kubernetes.io/docs/) - Kubernetes fundamentals
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs) - Infrastructure as Code reference
- [Azure Well-Architected Framework](https://docs.microsoft.com/en-us/azure/architecture/framework/) - Cloud architecture principles

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This configuration is provided as-is for educational and reference purposes. Please review and test thoroughly before using in production environments. Ensure compliance with your organization's security and operational requirements.

---

**🎉 Ready to deploy secure, scalable AKS infrastructure? Follow the [Deployment Guide](./DEPLOYMENT-GUIDE.md) to get started!**