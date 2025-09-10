# Terraform
## Open Tasks
- [wip] Enable VNET Integration from Terraform, each cluster in it's own VNET
   (https://github.com/hashicorp/terraform-provider-azurerm/issues/27640)
- [wip] Enable Private Kubernetes API Server, but configurable via Terraform variable (default public)
- [ ] Enable classic Private Cluster
- [check] Status of the Konnectivity Agent, what if it remains deployed?
- [✅] Classic VNET Hub and Spoke model
    Options:
    - [✅] Peer to existing Hub (UDR to default Gateway)
- [✅] Frontend/Public Cluster can reach private/backend cluster directly without Application Gateway, e.g. directly to internal load balancer

## Application specific setup (for each)
- [✅] Should every cluster have it's own private link subnet? No
- [✅] Applications always belong to ONE cluster. And should only had WI federation to a service account in that cluster.
- [✅] Each application should have it's own WAF policy
    - [✅] Attached to the HTTP Listener of the application gateway
- [✅] What is in the application config? 
      - name
- [✅] What is create per application
    - [✅] Create Key Vault for each application
    - [✅] Create SQL Database for each application with Private Endpoint
    - [✅] Create Workload Identity and Management Identity
    - [✅] Create RBAC for the Managed Identity
    - [✅] all with private links/endpoints
    - [✅] Kubernetes Namespace and Service Account
    - [✅] Output Private Links IP and FQDN/ Generate Network Policy Yaml / Example deployment yaml
    - [✅] App specific resources should go into their own resource group
    - [✅] Move SQL Private links to the app resource group
- [ ] Each "security scope" needs it's own identity. E.g. frontend vs backend

# Infra Miscellanous
- [✅] move application gateway stuff and network stuff into a specific resource group
- [✅] remove the private dns zones creation and modify the private endpoint in order to setup the private dns zone links to the existing private dns zones
- [✅] change the configuration of the vnet in order to use the existing Firewall Ipv4 192.168.0.4 on the Hub as a DNS Server
- [✅] managing the retention (short term and long term) of the SQL Server Backup
- [check] create backup vault if there is a storage account blob (new)
    - [check] backup vault must have his managed identity activated (new)
    - [check] the system managed identity of each backup vault must be applyed with a specific role on the storage account in order to permit the backup to works (new)
    - [ ] policy must be managable (new)
- [✅] add the system assign managed identity used by application gateway on the keyvault of each application as Keyvault Secret user in order to access the certificate of each app 
- [ ] setup the entraID group as admin of SQL server as a variabile in input in order based on the environment. stage and prod must should have one group as admin defined, dev and test another (new)
- [ ] define variables for setup the resource SKU (ex: application gateway zone redundancy, storage accout SKU, backup vault sku, aks node pool number, sku and zone redundancy) (new)
- [ ] support destroy from terraform (new)

## INGRESS
- [✅] switch to Istio instead of nginx

# AKS
## Ingress/Istio
- [ ] Echo Service
- [ ] Istio Gateway/Service to Echo Service

## Network Policies
- [✅] Default Network Policies (in: infra/k8s/default-networkpolicy.yaml)
       (we posponed on cluster wide policies until it's supported from AKS natively (or maybe with Kyverno))
- [wip] App Specific Policies (L7 FQDN)
- [ ] Andre: Prepare UDR
- [ ] Next time: Outbound Traffic (Hub Firewall)

# CODE ORGANIZATION / REFACTORING
- [ ] Extract Terraform into clear layer modules: core network, security, platform (AKS), per-app (new)
- [ ] Introduce a modules/README per module with inputs/outputs table (new)
- [ ] Separate shared app baseline vs per-application resource groups logic (new)
- [ ] Add Makefile or task script to standardize apply/plan flows (new)
- [ ] Verify the depends_on usage is optimal (new)

# DOCUMENTATION ALIGNMENT
- [ ] Unify naming/style across *.md (architecture vs infra vs deployment) (new)
- [ ] Add master index section into README linking to all scenario guides (new)
- [ ] Ensure each doc lists prereqs + outputs (new)
- [ ] Generate (script/manual) diagram export consistency (new)

# DEVX
- [✅] instead of hardcoding it in terraform.tf, pass the values in from the command line