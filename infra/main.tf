# Main Terraform Configuration
# Production-ready AKS Cluster with Secure Baseline Architecture

# This configuration creates a complete AKS infrastructure following Microsoft's
# secure baseline recommendations with the following components:
#
# 1. Base Infrastructure (base-infrastructure.tf)
#    - Resource Group, VNet, Subnets, NSGs
#
# 2. Security Layer (security-layer.tf)
#    - Azure Firewall with egress control
#    - Key Vault with private endpoint
#    - Storage Account with private endpoint
#    - SQL Server with private endpoint
#    - Private DNS zones
#
# 3. AKS Cluster (aks-cluster.tf)
#    - AKS with CNI Overlay and Cilium eBPF
#    - Workload Identity integration
#    - CSI Secrets Store Driver
#    - Container Registry (optional)
#
# 4. Ingress Layer (ingress-layer.tf)
#    - Application Gateway with WAF
#    - NGINX Ingress Controller (internal)
#    - Sample application deployment
#
# 5. SSL Certificates (ssl-cert.tf)
#    - Self-signed certificate for demo
#    - Key Vault integration
#
# 6. Monitoring (monitoring.tf)
#    - Log Analytics and Application Insights
#    - Diagnostic settings for all resources
#    - Alerts and saved queries
#
# Architecture Flow:
# Internet ’ App Gateway (Public IP + WAF) ’ NGINX Ingress (Internal LB) ’ 
# Cilium eBPF ’ Pods ’ Azure Firewall (Egress) ’ Internet
#
# All Azure services use private endpoints only.
# Only the Application Gateway has a public IP address.

# The actual resources are defined in the separate .tf files