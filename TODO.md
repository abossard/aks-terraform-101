# Open Tasks
- [wip] Enable VNET Integration from Terraform, each cluster in it's own VNET
- [wip] Enable Private Kubernetes API Server, but configurable via Terraform variable (default public)
- [check] Status of the Konnectivyt Agent, what if it remains deployed?
- [✅] Classic VNET Hub and Spoke model
    Options:
    - [✅] Peer to existing Hub (UDR to default Gateway)
- [✅] Frontend/Public Cluster can reach private/backend cluster directly without Application Gateway, e.g. directly to internal load balancer
# Application specific setup (for each)
- [✅] Should every cluster have it's own private link subnet? No
- [✅] Applications always belong to ONE cluster. And should only had WI federation to a service account in that cluster.
- [✅] Each application should have it's own WAF policy
    - [✅] Attached to the HTTP Listenever of the application gateway
- [✅] What is in the application config? 
      - name
- [ ] What is create per application
    - [✅] Create Key Vault for each application
    - [✅] Create SQL Database for each application with Private Endpoint
    - [✅] Create Workload Identity and Management Identity
    - [✅] Create RBAC for the Managed Identity
    - [✅] all with private links/endpoints
    - [✅] Kubernetes Namespace and Service Account
    - [✅] Output Private Links IP and FQDN/ Generate Network Policy Yaml / Example deployment yaml
    - [✅] App specific resources should go into their own resource group
    - [✅] Move SQL Private links to the app resource group


# Example Application
- [ ] Try to deploy application

# INGRESS
- [ ] Update default nginx ingress controller to private instead of creating a new nginx ingress controller
- [ ] switch to Istio instead of nginx

# DEVX
- [✅] instead of hardcoding it in terraform.tf, pass the values in from the command line