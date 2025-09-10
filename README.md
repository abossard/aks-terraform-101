# AKS Terraform 101 — concise guide

This repo provisions an AKS environment with secure networking, App Routing (managed NGINX), Key Vault integration, and useful generated artifacts to help you operate the cluster.

## Quick start

1) Configure variables
- Copy `infra/terraform.tfvars.example` to `infra/terraform.tfvars` and adjust values (env/project/region).

2) Plan & apply
- From VS Code: run the task “terraform init -upgrade && validate/plan” (or run Terraform manually in `infra/`).
- Apply when ready:
    - `terraform -chdir=infra apply`

3) Get cluster credentials
```bash
az aks get-credentials \
    --resource-group <rg-name> \
    --name <aks-name>
kubectl get nodes
```

## Kubernetes cluster bootstrap
- create service accounts (generated from infra/k8s/serviceaccount.tmpl.yaml)
- add network policies (default namespace policy in infra/k8s/default-networkpolicy.yaml)
- istio configuration (example in infra/k8s/examples/istio-multiapp-deployment.yaml)


## VNET Integration
- check that you're using a supported region: https://learn.microsoft.com/azure/aks/api-server-vnet-integration
- make sure that you have the respective providers registered (check with the az aks update command in the infra/k8s/generated/private-cluster-setup.sh script).
## Where things are

- Terraform (infrastructure)
    - `infra/*.tf` — main IaC files (AKS, VNet/Subnets/NSGs, Key Vault, App GW/WAF, identities, monitoring)
    - `infra/terraform.tfvars(.example)` — environment-specific inputs
- Kubernetes manifests (generated)
    - `infra/k8s/generated/`
        - `*-nginx-internal-controller.yaml` — per-cluster App Routing internal NGINX controller CR
        - `*-serviceaccount.yaml` — workload identity service account
        - `*-cluster-setup.sh` — helper script to connect/apply core K8s bits
- Kubernetes examples (manually applied)
    - `infra/k8s/examples/echo-server.yaml` — minimal echo app with two routes:
        - `/` → `echo-root-svc`
        - `/v1` → `echo-v1-svc`
- Cheatsheets
    - `infra/cheatsheets/generated/` — per-cluster quick commands and URLs
