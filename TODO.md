# Terraform
## Open Tasks
- [wip] Enable VNET Integration from Terraform, each cluster in it's own VNET
- [wip] Enable Private Kubernetes API Server, but configurable via Terraform variable (default public)
- [ ] Enable classic Private Cluster
- [check] Status of the Konnectivyt Agent, what if it remains deployed?
- [✅] Classic VNET Hub and Spoke model
    Options:
    - [✅] Peer to existing Hub (UDR to default Gateway)
- [✅] Frontend/Public Cluster can reach private/backend cluster directly without Application Gateway, e.g. directly to internal load balancer
## Application specific setup (for each)
- [✅] Should every cluster have it's own private link subnet? No
- [✅] Applications always belong to ONE cluster. And should only had WI federation to a service account in that cluster.
- [✅] Each application should have it's own WAF policy
    - [✅] Attached to the HTTP Listenever of the application gateway
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

# Infra Miscellanous
- [✅] move application gateway stuff and network stuff into a specific resource group
- [✅] remove the private dns zones creation and modify the private endpoint in order to setup the private dns zone links to the existing private dns zones
- [✅] change the configuration of the vnet in order to use the existing Firewall Ipv4 192.168.0.4 on the Hub as a DNS Server
- [✅] managing the retention (short term and long term) of the SQL Server Backup
- [check] create backup vault if there is a storage account blob
    - [check] backup vault must have his managed identity activated
    - [check] the system managed identity of each backup vault must be applyed with a specific role on the storage account in order to permit the backup to works
    - [ ] policy must be managable
- [✅] add the system assign managed identity used by application gateway on the keyvault of each application as Keyvault Secret user in order to access the certificate of each app 
- [ ] setup the entraID group as admin of SQL server as a variabile in input in order based on the environment. stage and prod must should have one group as admin defined, dev and test another
- [ ] define variabiles for setup the resource SKU (ex: application gateway zone redundancy, storage accout SKU, backup vault sku, aks node pool number, sku and zone redundancy)


## INGRESS
- [✅] switch to Istio instead of nginx

# AKS
## Ingress/Istio
- [ ] Echo Service
- [ ] Istio Gateway/Service to Echo Service

## Network Policies
- [ ] Andre: Default Network Policies
- [ ] Andre: App Specific Policies
- [ ] Andre: Prepare UDR
- [ ] Next time: Outbound Traffic (Hub Firewall)

# POLICIES
- [ ] Cluster Internal policies
  - [ ] Default Policy in each namespace

# DEVX
- [✅] instead of hardcoding it in terraform.tf, pass the values in from the command line