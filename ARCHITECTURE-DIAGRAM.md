## AKS Secure Baseline – Architecture Diagram

This diagram visualizes the infrastructure defined in `infra/*.tf`: dual AKS clusters (public/backend) behind Application Gateway (WAF), private endpoints to data services, Azure Firewall egress, workload identities, monitoring, and **secure NSG configuration with inter-cluster isolation**.

```mermaid
%%{init: {'theme':'neutral','flowchart':{'curve':'basis'}} }%%
flowchart LR

  %% Top-level logical zones
  subgraph Internet
    NET["🌐 Internet"]
  end

  subgraph RG["Resource Group: rg-${environment}-${project}-${location_code}-001"]

    %% Networking with NSG Security Zones
    subgraph VNET["VNet: vnet-${environment}-${project}-${location_code}-001\n10.240.0.0/16"]
      subgraph SNET_AGW["🔒 Ingress Zone: snet-agw-${environment}-${location_code}-001\nNSG: nsg-agw-${environment}-${location_code}-001"]
        PIP_AGW["Public IP (Standard)"]
        AGW_ID["UAMI: id-agw-${environment}-${location_code}-001"]
      end

      subgraph SNET_PUB["🔒 Public Cluster Zone: snet-public-${environment}-${location_code}-001\n(10.32.0.0/24)\nNSG: nsg-public-${environment}-${location_code}-001"]
        AKS_PUB["AKS Cluster: aks-${environment}-${project}-public-${location_code}-001\n- CNI Overlay + Cilium\n- OIDC & Workload Identity\n- Outbound: loadBalancer"]
        NGINX_PUB["NGINX Ingress (Internal LB)\nstatic IP: cluster_configs.public.nginx_internal_ip"]
      end

      subgraph SNET_BACK["🔒 Backend Cluster Zone: snet-backend-${environment}-${location_code}-001\n(10.32.4.0/24)\nNSG: nsg-backend-${environment}-${location_code}-001"]
        AKS_BACK["AKS Cluster: aks-${environment}-${project}-backend-${location_code}-001\n- CNI Overlay + Cilium\n- OIDC & Workload Identity\n- Outbound: loadBalancer"]
        NGINX_BACK["NGINX Ingress (Internal LB)\nstatic IP: cluster_configs.backend.nginx_internal_ip"]
      end

      subgraph SNET_PE["🔒 Private Endpoints Zone: snet-pe-${environment}-${location_code}-001\n(10.240.3.0/24)\nNSG: nsg-pe-${environment}-${location_code}-001"]
        PE_KV["PE: Key Vault"]
        PE_ST_BLOB["PE: Storage (blob)"]
        PE_ST_FILE["PE: Storage (file)"]
        PE_SQL["PE: SQL Server"]
      end

      subgraph SNET_API["🔒 API Server Zones: snet-apiserver-*-${environment}-${location_code}-001\n(10.240.200.0/24 parent)\nNSGs: nsg-apiserver-*-${environment}-${location_code}-001"]
        API_PUB["API Server Subnet\n(Public Cluster)"]
        API_BACK["API Server Subnet\n(Backend Cluster)"]
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

  %% Allowed Traffic flows (Green - Secure Paths)
  NET -->|"✅ HTTPS 80,443"| PIP_AGW --> AGW
  AGW -->|"✅ HTTPS app.yourdomain.com\nNSG: AllowClusterSubnets"| NGINX_PUB
  AGW -->|"✅ HTTPS api.yourdomain.com\nNSG: AllowClusterSubnets + WAF rules"| NGINX_BACK

  %% AKS internal routing to apps
  NGINX_PUB --> AKS_PUB
  NGINX_BACK --> AKS_BACK

  %% Blocked Traffic flows (Red - Security Boundaries)
  SNET_PUB -.->|"❌ BLOCKED\nNSG: DenyInterClusterCommunication\nPriority: 500"| SNET_BACK
  SNET_BACK -.->|"❌ BLOCKED\nNSG: DenyInterClusterCommunication\nPriority: 500"| SNET_PUB

  %% Allowed Private Endpoint Access (Blue - Data Plane)
  AKS_PUB -->|"✅ TCP 443,1433,5432\nNSG: AllowPrivateEndpoints"| PE_KV
  AKS_PUB -->|"✅ TCP 443,1433,5432\nNSG: AllowPrivateEndpoints"| PE_ST_BLOB
  AKS_PUB -->|"✅ TCP 443,1433,5432\nNSG: AllowPrivateEndpoints"| PE_SQL
  AKS_BACK -->|"✅ TCP 443,1433,5432\nNSG: AllowPrivateEndpoints"| PE_KV
  AKS_BACK -->|"✅ TCP 443,1433,5432\nNSG: AllowPrivateEndpoints"| PE_ST_BLOB
  AKS_BACK -->|"✅ TCP 443,1433,5432\nNSG: AllowPrivateEndpoints"| PE_SQL

  %% API Server Communication (Purple - Control Plane)
  API_PUB -->|"✅ TCP 443,10250\nNSG: AllowClusterSubnet"| AKS_PUB
  API_BACK -->|"✅ TCP 443,10250\nNSG: AllowClusterSubnet"| AKS_BACK

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
  classDef security fill:#ffebee,stroke:#f44336,stroke-width:2px;

  class VNET,SNET_AGW,SNET_PUB,SNET_BACK,SNET_FW,SNET_PE,SNET_API,PDNS net;
  class AGW,PIP_AGW,KV,SA,SQLS,SQLDB,ACR svc;
  class AZFW,FW_PIP sec;
  class ID_PUB,ID_BACK,AGW_ID,ID_SQL_APP id;
  class LAW,APPI,AMW,DCE,DCR mon;
```

## NSG Security Architecture

### Security Zones and Traffic Control

The infrastructure implements **zero-trust network segmentation** with the following security zones:

#### 🔒 **Zone Isolation Matrix**

| Source Zone | Target Zone | Access | NSG Rule | Priority |
|-------------|-------------|--------|----------|----------|
| Internet | Ingress (AGW) | ✅ HTTP/S 80,443 | AllowHttpsInbound | 1000 |
| Ingress (AGW) | Public Cluster | ✅ HTTP/S 80,443 | AllowClusterSubnets | 1000 |
| Ingress (AGW) | Backend Cluster | ✅ HTTP/S 80,443 | AllowClusterSubnets | 1000 |
| **Public Cluster** | **Backend Cluster** | ❌ **BLOCKED** | **DenyInterClusterCommunication** | **500** |
| **Backend Cluster** | **Public Cluster** | ❌ **BLOCKED** | **DenyInterClusterCommunication** | **500** |
| Any Cluster | Private Endpoints | ✅ TCP 443,1433,5432 | AllowPrivateEndpoints | 1000 |
| API Server | Cluster Nodes | ✅ TCP 443,10250 | AllowClusterSubnet | 1000 |
| External | Private Endpoints | ❌ **BLOCKED** | DenyAllInbound | 4000 |

#### 🛡️ **NSG Rules Summary**

##### **Cluster Subnet NSGs** (2 NSGs: public + backend)
```
INBOUND:
├── 1000: Allow Application Gateway → Cluster (TCP 80,443)
├── 1100: Allow Azure Load Balancer → Cluster (Any)
├── 1200: Allow API Server → Cluster (TCP 443,10250)
└── 4096: DENY ALL (Azure default)

OUTBOUND:
├── 500:  🚫 DENY Inter-Cluster Communication [CRITICAL ISOLATION]
├── 1000: Allow → Private Endpoints (TCP 443,1433,5432)
├── 1100: Allow → Azure Service Tags (TCP 443)
├── 1200: Allow → Hub VNet (Any) [if peering enabled]
└── 4000: DENY ALL [if enable_strict_nsg_outbound_deny=true]
```

##### **Application Gateway Subnet NSG**
```
INBOUND:
├── 1000: Allow Internet → AppGW (TCP 80,443)
├── 1100: Allow GatewayManager → AppGW (TCP 65200-65535)
├── 1200: Allow AzureLoadBalancer → AppGW (Any)
└── 4096: DENY ALL (Azure default)

OUTBOUND:
├── 1000: Allow → Cluster Subnets (TCP 80,443)
├── 1100: Allow → Private Endpoints (TCP 443)
├── 1200: Allow → Azure Services (TCP 443) [cert management]
├── 1300: Allow → Hub VNet (Any) [if peering enabled]
└── 4000: DENY ALL [if enable_strict_nsg_outbound_deny=true]
```

##### **Private Endpoints Subnet NSG**
```
INBOUND:
├── 1000: Allow VNet Subnets → PE (TCP 443,1433,5432,3306)
└── 4000: 🚫 DENY ALL [ALWAYS STRICT]

OUTBOUND:
├── 1000: Allow → Azure Service Tags (TCP 443,1433,5432)
├── 1100: Allow → Hub VNet (Any) [if peering enabled]
└── 4000: DENY ALL [if enable_strict_nsg_outbound_deny=true]
```

##### **API Server Subnet NSGs** (2 NSGs: one per cluster)
```
INBOUND:
├── 1000: Allow AzureCloud → API Server (TCP 443)
└── 4096: DENY ALL (Azure default)

OUTBOUND:
├── 1000: Allow → Corresponding Cluster (TCP 443,10250)
├── 1100: Allow → Azure Services (TCP 443)
├── 1200: Allow → Hub VNet (Any) [if peering enabled]
└── 4000: DENY ALL [if enable_strict_nsg_outbound_deny=true]
```

### Configuration Modes

#### **Development Mode** (`enable_strict_nsg_outbound_deny = false`)
- ✅ Core security boundaries enforced (inter-cluster isolation)
- ✅ Azure default outbound rules allow necessary services
- ✅ No explicit deny-all rule
- 🎯 **Use case**: Development, testing, initial deployment

#### **Production Mode** (`enable_strict_nsg_outbound_deny = true`)
- ✅ All development mode protections
- ✅ **Explicit deny-all outbound rule** (Priority 4000)
- ✅ Hub/firewall routing required for internet access
- 🎯 **Use case**: Production with hub-spoke + Azure Firewall

#### **Hub Integration** (`enable_vnet_peering = true`)
- ✅ Additional outbound rules to hub VNet
- ✅ Supports Azure Firewall egress routing
- ✅ Centralized network security management

### Security Benefits

- 🛡️ **Inter-Cluster Isolation**: Public and backend clusters cannot communicate directly
- 🔒 **Private Endpoint Protection**: Only authorized subnets can access data services
- 🚫 **Default Deny**: Optional strict mode blocks all unauthorized outbound traffic
- 📍 **Service Tag Precision**: Uses specific Azure service tags instead of broad internet access
- 🎯 **Configurable Security**: Can start permissive and tighten gradually
- 🔄 **Hub-Spoke Ready**: Supports centralized security through Azure Firewall

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
