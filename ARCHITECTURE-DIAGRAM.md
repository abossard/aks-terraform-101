## AKS Secure Baseline – Architecture Diagram

This diagram visualizes the infrastructure defined in `infra/*.tf`: dual AKS clusters (public/backend) behind Application Gateway (WAF), private endpoints to data services, Azure Firewall egress, workload identities, and monitoring.

```mermaid
%%{init: {'theme':'neutral','flowchart':{'curve':'basis'}} }%%
flowchart LR

  %% Top-level logical zones
  subgraph Internet
    NET["🌐 Internet"]
  end

  subgraph RG["Resource Group: rg-${environment}-${project}-${location_code}-001"]

    %% Networking
    subgraph VNET["VNet: vnet-${environment}-${project}-${location_code}-001\n10.240.0.0/16"]
      subgraph SNET_AGW["Subnet: snet-agw-${environment}-${location_code}-001"]
        PIP_AGW["Public IP (Standard)"]
        AGW_ID["UAMI: id-agw-${environment}-${location_code}-001"]
      end

      subgraph SNET_PUB["Subnet: snet-public-${environment}-${location_code}-001\n(10.240.0.0/24)"]
        AKS_PUB["AKS Cluster: aks-${environment}-${project}-public-${location_code}-001\n- CNI Overlay + Cilium\n- OIDC & Workload Identity\n- Outbound: loadBalancer"]
        NGINX_PUB["NGINX Ingress (Internal LB)\nstatic IP: cluster_configs.public.nginx_internal_ip"]
      end

      subgraph SNET_BACK["Subnet: snet-backend-${environment}-${location_code}-001\n(10.240.4.0/24)"]
        AKS_BACK["AKS Cluster: aks-${environment}-${project}-backend-${location_code}-001\n- CNI Overlay + Cilium\n- OIDC & Workload Identity\n- Outbound: loadBalancer"]
        NGINX_BACK["NGINX Ingress (Internal LB)\nstatic IP: cluster_configs.backend.nginx_internal_ip"]
      end

      subgraph SNET_FW["Subnet: AzureFirewallSubnet\n(10.240.2.0/24)"]
        FW_PIP["Public IP (Firewall)"]
        AZFW["Azure Firewall (Standard)\nPolicy + Egress rules"]
      end

      subgraph SNET_PE["Subnet: snet-pe-${environment}-${location_code}-001\n(10.240.3.0/24)"]
        PE_KV["PE: Key Vault"]
        PE_ST_BLOB["PE: Storage (blob)"]
        PE_ST_FILE["PE: Storage (file)"]
        PE_SQL["PE: SQL Server"]
      end
    end

    %% Ingress – Application Gateway
    AGW["Application Gateway (WAF_v2)\nWAF Policy: waf-policy-${environment}-${location_code}-001\nSSL: wildcard cert"]

    %% Data plane services
    KV["Key Vault: kv-${environment}${project}{rand}\n- RBAC enabled\n- Purge protection"]
    SA["Storage Account: st${environment}${project}${location_code}{rand}\nHNS: enabled"]
    SQLS["SQL Server: sql-main-${environment}-${location_code}-{rand}\nAAD admin enabled"]
    SQLDB["SQL DB: sqldb-app-${environment}-${location_code}\nS1"]

    %% Private DNS Zones
    subgraph PDNS["Private DNS Zones"]
      DNS_KV["privatelink.vaultcore.azure.net"]
      DNS_BLOB["privatelink.blob.core.windows.net"]
      DNS_FILE["privatelink.file.core.windows.net"]
      DNS_SQL["privatelink.database.windows.net"]
    end

    %% Container Registry (optional)
    ACR["ACR: acr${environment}${project}${location_code}{rand}\nadmin: false\npublic network: true"]

    %% Monitoring
    LAW["Log Analytics Workspace"]
    APPI["Application Insights (workspace-based)"]
    AMW["Azure Monitor Workspace (Prometheus)"]
    DCE["Data Collection Endpoint (DCE)"]
    DCR["Data Collection Rule (DCR)\nMicrosoft-PrometheusMetrics"]

    %% Identities & RBAC
    ID_PUB["UAMI: id-workload-public-${environment}-${location_code}-001"]
    ID_BACK["UAMI: id-workload-backend-${environment}-${location_code}-001"]
    ID_SQL_APP["UAMI: id-sql-app-${environment}-${location_code}-001"]

  end

  %% Traffic flow
  NET --> PIP_AGW --> AGW
  AGW -->|HTTPS app.yourdomain.com| NGINX_PUB
  AGW -->|HTTPS api.yourdomain.com - WAF rules| NGINX_BACK

  %% AKS internal routing to apps
  NGINX_PUB --> AKS_PUB
  NGINX_BACK --> AKS_BACK

  %% Egress (conceptual) via Azure Firewall
  AKS_PUB -. egress .-> AZFW
  AKS_BACK -. egress .-> AZFW
  AZFW --> FW_PIP --> NET

  %% Private Endpoints to services
  PE_KV --> KV
  PE_ST_BLOB --> SA
  PE_ST_FILE --> SA
  PE_SQL --> SQLS
  SQLS --> SQLDB

  %% DNS links
  PDNS --- VNET
  PE_KV -. register .- DNS_KV
  PE_ST_BLOB -. register .- DNS_BLOB
  PE_ST_FILE -. register .- DNS_FILE
  PE_SQL -. register .- DNS_SQL

  %% Monitoring links
  AKS_PUB -->|OMS agent| LAW
  AKS_BACK -->|OMS agent| LAW
  APPI --> LAW
  DCR --> AMW
  DCR -.-> DCE
  AKS_PUB -->|DCRA| DCR
  AKS_BACK -->|DCRA| DCR

  %% ACR pull (optional)
  AKS_PUB -. AcrPull kubelet .-> ACR
  AKS_BACK -. AcrPull kubelet .-> ACR

  %% Workload Identity & RBAC
  AKS_PUB -. OIDC .-> ID_PUB
  AKS_BACK -. OIDC .-> ID_BACK
  ID_PUB -. Secrets User .-> KV
  ID_BACK -. Secrets User .-> KV
  ID_PUB -. Blob Data Contributor .-> SA
  ID_BACK -. Blob Data Contributor .-> SA
  ID_PUB -. SQL DB Contributor .-> SQLDB
  ID_BACK -. SQL DB Contributor .-> SQLDB

  %% App Gateway identity to Key Vault for certs
  AGW_ID -. Key Vault Secrets User .-> KV
  AGW -. uses cert .-> KV

  %% SQL App identity & database role
  ID_SQL_APP -. owner (sqlsso) .-> SQLDB
  ID_SQL_APP --> KV

  %% Notes/Legend
  classDef svc fill:#e3f2fd,stroke:#90caf9,stroke-width:1px;
  classDef net fill:#f5f5f5,stroke:#bdbdbd,stroke-width:1px;
  classDef sec fill:#fff3e0,stroke:#ffb74d,stroke-width:1px;
  classDef id fill:#f3e5f5,stroke:#ce93d8,stroke-width:1px;
  classDef mon fill:#e8f5e9,stroke:#a5d6a7,stroke-width:1px;

  class VNET,SNET_AGW,SNET_PUB,SNET_BACK,SNET_FW,SNET_PE,PDNS net;
  class AGW,PIP_AGW,KV,SA,SQLS,SQLDB,ACR svc;
  class AZFW,FW_PIP sec;
  class ID_PUB,ID_BACK,AGW_ID,ID_SQL_APP id;
  class LAW,APPI,AMW,DCE,DCR mon;
```

### What’s shown
- Per Terraform: VNet and subnets for App Gateway, AKS clusters (public/backend), Azure Firewall, and Private Endpoints
- Ingress path: Internet → App Gateway (WAF) → NGINX Ingress (internal IP) → AKS pods
- Egress path: AKS nodes → Azure Firewall → Internet (policy-based; UDR association optional)
- Private endpoints for Key Vault, Storage (blob/file), and SQL Server, with Private DNS zones linked to the VNet
- Workload identities per cluster and RBAC to KV/Storage/SQL; App Gateway’s UAMI to Key Vault for TLS secrets
- Optional ACR with AcrPull to cluster kubelets
- Monitoring with Log Analytics, workspace-based Application Insights, Prometheus (AMW + DCR/DCE) associated to both clusters

### Previewing the diagram
- In VS Code, install a Mermaid preview extension (e.g., “Markdown Preview Mermaid Support”), then open this file and preview.
- Or generate an image via Mermaid CLI (optional).

### Also useful (auto-generated graph)
If you want a generic dependency graph straight from Terraform, you can run (optional):
- terraform graph | dot -Tsvg > tf-graph.svg
This renders Terraform’s resource graph (less domain-specific than the curated diagram above).
