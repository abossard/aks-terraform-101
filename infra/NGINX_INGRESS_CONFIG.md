# NGINX Ingress Static IP Configuration

This document explains how to configure NGINX ingress controllers with static internal IPs using Kubernetes annotations.

## Overview

Instead of pre-creating Azure Load Balancer resources, we use Kubernetes service annotations to assign specific static internal IPs to NGINX ingress controllers. This approach is simpler and leverages Azure's automatic Load Balancer creation.

## Static IP Assignments

The Terraform configuration reserves the following internal IPs for NGINX ingress controllers:

- **Public Cluster**: `10.240.0.100` (subnet: `10.240.0.0/24`)
- **Backend Cluster**: `10.240.4.100` (subnet: `10.240.4.0/24`)

These IPs are calculated using `cidrhost(subnet_cidr, 100)` to ensure they're within the subnet range but unlikely to conflict with other resources.

## Required Kubernetes Annotations

When deploying NGINX ingress controllers, use these annotations on the LoadBalancer service:

### Core Annotations
```yaml
service.beta.kubernetes.io/azure-load-balancer-internal: "true"
service.beta.kubernetes.io/azure-load-balancer-static-ip: "<STATIC_IP>"
service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "<SUBNET_NAME>"
```

### Example for Public Cluster
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-ingress-controller
  namespace: kube-system
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
    service.beta.kubernetes.io/azure-load-balancer-static-ip: "10.240.0.100"
    service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "snet-public-prod-eus2-001"
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
    name: http
  - port: 443
    targetPort: 443
    name: https
  selector:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/component: controller
```

### Example for Backend Cluster
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-ingress-controller
  namespace: kube-system
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
    service.beta.kubernetes.io/azure-load-balancer-static-ip: "10.240.4.100"
    service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "snet-backend-prod-eus2-001"
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
    name: http
  - port: 443
    targetPort: 443
    name: https
  selector:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/component: controller
```

## Application Routing add-on (Managed NGINX) with static private IP

The add-on uses a CRD named `NginxIngressController`. Create an internal controller and bind it to the reserved IP using annotations:

```yaml
apiVersion: approuting.kubernetes.azure.com/v1alpha1
kind: NginxIngressController
metadata:
  name: nginx-internal
  namespace: app-routing-system
spec:
  ingressClassName: nginx-internal
  controllerNamePrefix: nginx-internal
  loadBalancerAnnotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
    service.beta.kubernetes.io/azure-load-balancer-ipv4: "10.240.0.100"
    service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "snet-public-prod-eus2-001"
```

Apply the ready-made template in `infra/k8s/nginx-internal-controller.yaml` and replace `${NGINX_INTERNAL_IP}` and `${AKS_SUBNET_NAME}`. The IPv4 annotation is preferred over `spec.loadBalancerIP` per AKS docs.

## Getting Configuration Values from Terraform

Use these Terraform outputs to get the required values for NGINX configuration:

```bash
# Get NGINX internal IPs
terraform output nginx_internal_ips

# Get cluster subnet names (use with nginx_ingress_config below)
terraform output -json cluster_subnet_ids | jq

# Get full cluster configuration
terraform output aks_clusters
```

Example output usage:
```bash
PUBLIC_IP=$(terraform output -json nginx_internal_ips | jq -r '.public')
BACKEND_IP=$(terraform output -json nginx_internal_ips | jq -r '.backend')
# From combined config
PUBLIC_SUBNET=$(terraform output -json nginx_ingress_config | jq -r '.public.subnet_name')
BACKEND_SUBNET=$(terraform output -json nginx_ingress_config | jq -r '.backend.subnet_name')
```

## Application Gateway Integration

The Application Gateway is automatically configured to target these static IPs:

- **app.yourdomain.com** → `10.240.0.100` (Public cluster NGINX)
- **api.yourdomain.com** → `10.240.4.100` (Backend cluster NGINX)

## Benefits of This Approach

✅ **Predictable IPs**: Known IP addresses that don't change
✅ **No pre-created resources**: Azure creates Load Balancers automatically
✅ **Simple configuration**: Just Kubernetes annotations
✅ **Terraform integration**: IPs available as outputs for automation
✅ **Health checking**: Application Gateway can health check the Load Balancers
✅ **Cost effective**: Only pay for Load Balancers when services are running

## Troubleshooting

### IP Assignment Issues
- Ensure the static IP is within the subnet CIDR range
- Verify the IP isn't already in use by another resource
- Check that the subnet name matches exactly

### Service Not Getting IP
- Verify AKS has permissions to create Load Balancers
- Check the service logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=ingress-nginx`
- Ensure the cluster has Azure CNI networking enabled

### Application Gateway Health Checks Failing
- Verify NGINX is responding on port 80/443
- Check that health check endpoint `/healthz` is available
- Ensure NSG rules allow Application Gateway subnet to reach NGINX IPs