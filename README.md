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
## VNET Integration
- check that you're using a supported region: https://learn.microsoft.com/azure/aks/api-server-vnet-integration
- make sure that you have the respective providers registered (check with the az aks update command in the infra/k8s/generated/backend-cluster-setup.sh script).
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

## App Routing (internal only)

- The repo generates an internal NGINX controller CR with annotations to use a private LoadBalancer in your AKS subnet.
- Apply (if not already applied by your setup script):
```bash
kubectl apply -f infra/k8s/generated/<cluster>-nginx-internal-controller.yaml
```
- You can also make the default controller internal-only or disable it entirely:
    - Internal: `az aks approuting update --resource-group <rg> --name <aks> --nginx Internal`
    - None (disable): `az aks approuting update --resource-group <rg> --name <aks> --nginx None`

## Test the ingress

```bash
kubectl apply -f infra/k8s/examples/echo-server.yaml
2) Get the internal IP of the controller service:
```bash
kubectl -n app-routing-system get svc nginx-internal-0 -o jsonpath='{.status.loadBalancer.ingress[0].ip}{"\n"}'
```
```bash
curl -i http://<INTERNAL_IP>/
curl -i http://<INTERNAL_IP>/v1

## Fast Terraform tips


The SQL logical server deploys with:
- Private Endpoint (default `enable_sql_private_endpoint = true`)
- Public access initially enabled (`sql_public_network_enabled = true`) for easy bootstrap

Harden after validation:
```bash
terraform output -raw sql_server_fqdn
nslookup $(terraform output -raw sql_server_fqdn)   # Should resolve private IP
```
Then set in `infra/terraform.tfvars`:
```hcl
sql_public_network_enabled = false
```
Re-apply:
```bash
terraform -chdir=infra plan
terraform -chdir=infra apply
```

Check outputs:
```bash
terraform output sql_public_network_enabled
terraform output sql_private_endpoint_private_ip
```

Keep `enable_sql_private_endpoint = true` unless you have an alternative private connectivity method.
- Speed up plan/apply/destroy for dev loops:
    - `export TF_CLI_ARGS_plan="-parallelism=30"`
    - `export TF_CLI_ARGS_apply="-parallelism=30"`
- Pre-register providers in Azure, then set `skip_provider_registration = true` in the azurerm provider.

## Recent highlights (last 2 days)
- Added example app: `infra/k8s/examples/echo-server.yaml` with `/` and `/v1` routes via `nginx-internal`.
- Ensured AKS identities have Network Contributor on the VNet to allow internal LoadBalancer creation (fixes 403 on subnets/read).
- Clarified internal-only App Routing usage and where to find generated manifests under `infra/k8s/generated/`.

To see exact commits locally:
- Added SQL Private Endpoint + public access toggle (`sql_public_network_enabled` / `enable_sql_private_endpoint`).

## Troubleshooting

- Internal LB pending: check events on the service for RBAC errors; ensure the AKS cluster identity has Network Contributor on the VNet.
- Health probes blocked: add NSG rules allowing `AzureLoadBalancer` to the node ports (or 80/443 depending on setup) in the AKS subnet NSG.