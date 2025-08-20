# Open Tasks
- [ ] Enable VNET Integration from Terraform, each cluster in it's own VNET
- [ ] Enable Private Kubernetes API Server, but configurable via Terraform variable (default public)

# Application specific setup (for each)
- [ ] Create Key Vault for each application
- [ ] Create SQL Database for each application with Private Endpoint
- [ ] Create Workload Identity and Mangement Identity
- [ ] Create RBAC for the Mananged Identity
- [ ] Output Private Links IP / Generate Network Policy Yaml
# Example Application
- [ ] Try to deploy application

# INGRESS
- [ ] Update default nginx ingress controller to private instead of creating a new nginx ingress controller