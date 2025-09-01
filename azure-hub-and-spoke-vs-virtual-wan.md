# Azure Hub-and-Spoke vs Azure Virtual WAN

Comprehensive, practitioner-focused comparison tailored for AKS-centric platform foundations. Includes decision guidance, migration notes, AKS nuances, and authoritative Microsoft Learn references.

## 1. Executive Overview
Both classic (customer-managed) hub-and-spoke and Azure Virtual WAN (vWAN) implement a hub-mediated transit model. The difference is in ownership and operational abstraction:

| Dimension | Hub-and-Spoke (You Manage) | Azure Virtual WAN (Microsoft Managed) |
|-----------|----------------------------|---------------------------------------|
| Hub Entity | Your VNet (fully customizable) | Virtual Hub (managed construct) |
| Transitive Routing | You design (peerings, UDRs, gateways, NVAs) | Built-in any-to-any (Std tier) |
| Branch / SD-WAN Onboarding | Manual per gateway | Partner/device automation |
| Multi-Region Expansion | New hubs + mesh/peering logic | Add hubs; automatic hub-to-hub mesh (Std) |
| Custom NVAs / Service Chaining | Full flexibility | Limited (supported NVAs & Firewall) |
| Hosting Shared Services (VMs, jump hosts) | In hub VNet | Not in virtual hub (move to a spoke) |
| Operational Overhead | Higher (lifecycle of each component) | Lower (managed gateways & routing) |
| Cost Profile | Component-based; cheaper at small scale | Aggregated service fees; scales with simplification |
| Advanced Traffic Engineering | Maximum flexibility | Abstracted; route tables & policies only |
| Ideal When | Need bespoke control / niche NVAs | Need rapid global, unified connectivity |

## 2. Conceptual Summary
Hub-and-spoke centralizes shared services you deploy. Virtual WAN centralizes connectivity primitives you consume. vWAN turns “network assembly” into “network subscription” using Microsoft’s global backbone.

## 3. Architecture & Routing Differences
### Hub-and-Spoke
- Peering-based design; spokes usually set `useRemoteGateways=true` to consume hub gateways.
- Spoke-to-spoke options: (a) hairpin via hub gateways/NVAs + UDRs, (b) direct VNet peering, (c) Azure Virtual Network Manager (AVNM) (not for vWAN topologies at time of writing).
- You manage: UDRs, NVA scaling, ExpressRoute/VPN gateways, optional Route Server for BGP.

### Azure Virtual WAN
- Virtual hubs are Microsoft-managed; you attach VNets via **VNet connections**.
- Standard tier supplies local + global VNet transit, branch ↔ branch, branch ↔ VNet, user VPN, ExpressRoute convergence.
- Routing fabric is managed; you optionally define hub route tables for traffic steering (e.g., to Azure Firewall in secured vHub).

## 4. Security & Segmentation
| Need | Hub-and-Spoke | Virtual WAN |
|------|---------------|------------|
| Central Firewall | Azure Firewall or any 3rd-party NVA | Azure Firewall (secured hub) or limited NVAs |
| East-West Inspection | Flexible NVA chains | Constrained to supported functions |
| Micro-Segmentation | NSG + UDR + Firewall policies | NSG + vHub route tables + Firewall policies |
| Forced Tunneling | Custom UDRs + NVAs | vHub route tables / Firewall Manager |
| Hosting DNS / Bastion / Jump Hosts | In hub VNet | Must place in a spoke VNet |

## 5. Operational Model
| Aspect | Hub-and-Spoke | Virtual WAN |
|--------|---------------|------------|
| Gateway lifecycle | You patch/scale | Platform-managed |
| Adding new branch/site | Manual config & scripting | SD-WAN / partner automation |
| Multi-region transit | Manual hub mesh / ER Global Reach | Auto hub mesh (Std) |
| Change blast radius | Fragmented resources | Central policy plane |
| Troubleshooting depth | Full introspection | Abstracted (diagnostics APIs) |

## 6. Cost Considerations (Qualitative)
Small/simple environments often spend less with DIY hub-and-spoke. At scale (many branches, regions, mixed VPN + ER + P2S) the operational and architectural consolidation of vWAN typically offsets its per-hub + data processing fees. Always model:
`total_regions × (sites + user cohorts + VNets) × projected traffic (Gbps)` and compare component SKUs vs vWAN pricing tiers.

## 7. Performance & Scale
| Factor | Hub-and-Spoke | Virtual WAN |
|--------|---------------|------------|
| Latency | Possible hairpins via hub NVAs | Optimized backbone transit |
| Throughput Mgmt | Gateway / NVA sizing | Up to 50 Gbps aggregate VNet ↔ VNet per hub (doc stated) |
| Global Reach | Manual design + ER Global Reach | Built-in hub-to-hub mesh (Std) |
| Spoke Count Growth | Peerings & route scaling overhead | Linear add (attach VNet) |

## 8. Feature Gaps & Constraints
| Capability | Hub-and-Spoke Advantage | vWAN Advantage |
|------------|-------------------------|---------------|
| Custom appliance portfolio | Broad | Limited supported list |
| Host workloads in hub | Yes | No |
| Complex service chaining | Easier | Restricted |
| Branch automation | Manual | Native partnering |
| Unified global transit | DIY | Native |

## 9. Decision Triggers
Choose **Hub-and-Spoke** if:
- You require bespoke routing manipulations (multi-NVA chains, advanced BGP influence, overlapping IP remediation techniques).
- You need unsupported NVAs or to host shared workloads inside the hub.
- Environment is single-region, low branch/user count, cost-sensitive.

Choose **Virtual WAN** if:
- Multi-region and/or >5–10 branches / significant remote user VPN needs.
- Desire unified convergence of S2S, P2S, ExpressRoute, and VNet transit.
- Need faster onboarding and reduced network operations toil.
- Strategic move to global expansion leveraging Microsoft backbone.

## 10. Migration Considerations (High-Level Steps)
1. Deploy vWAN + first virtual hub (parallel to existing hub VNet).
2. Attach test spoke VNet; validate ExpressRoute / VPN / P2S paths.
3. Dual-connect on-prem (temporary coexistence) ensuring symmetric routing.
4. Iteratively detach spokes from old hub, attach to virtual hub, remove UDR-based transit.
5. Decommission legacy hub gateways; convert old hub to “shared services” spoke.
6. Optionally refactor inspection to Azure Firewall (secured vHub) and phase out NVAs if no longer needed.
7. Optimize route tables; validate DNS & Private Endpoint resolution flows post-move.

## 11. AKS-Specific Lens
| AKS Concern | Hub-and-Spoke | Virtual WAN |
|-------------|---------------|------------|
| Private cluster control plane | Standard patterns | Same; transit simpler cross-region |
| Private Endpoints (ACR, Key Vault, SQL) | Manual centralized DNS & routing | Slightly less routing config; still DNS planning |
| Multi-region clusters / DR | Peering or global design complexity | Built-in global transit |
| Egress control (allowlists) | NVAs / Azure Firewall + UDR | Azure Firewall in secured hub centralizes policy |
| Dev/Test isolation | Peerings & segmentation constructs | VNet connection mgmt + route table isolation |
| Service Mesh / cross-cluster comms | Manual transitivity or direct peering | Native transit; can still peer selectively for latency |

## 12. Hybrid / Mixed Pattern
Common: Adopt vWAN for global and branch aggregation while retaining legacy hub VNet as a spoke hosting jump hosts, legacy NVAs, or specialized tooling until retired.

## 13. Risks & Edge Cases
| Edge Case | Watchpoint | Mitigation |
|-----------|-----------|------------|
| Overlapping IP ranges | Both architectures sensitive | IPAM + staged renumber prior to migration |
| Route asymmetry during migration | Dual hubs advertising routes | Stage changes; test symmetrical flows per spoke |
| Large east-west data volumes needing low latency | Hub hairpin overhead | Direct spoke peering (still possible) |
| Need Route Server in spoke + vWAN connection | vWAN forbids gateway/Route Server in connected spoke | Keep that VNet unattached or redesign roles |
| Complex multi-NVA chain | Limited in vWAN hub | Retain NVA chain in a spoke; steer via route tables |

## 14. Terraform Resource Mapping (Illustrative)
| Capability | Hub-and-Spoke Terraform (azurerm) | vWAN Terraform (azurerm) |
|-----------|----------------------------------|---------------------------|
| Hub VNet | `azurerm_virtual_network`, `azurerm_subnet` | (Spokes only; hub is `azurerm_virtual_hub`) |
| Peering | `azurerm_virtual_network_peering` | Not needed for transit (use `azurerm_virtual_hub_connection`) |
| VPN Gateway | `azurerm_virtual_network_gateway` | `azurerm_vpn_gateway` (in virtual hub) |
| ExpressRoute Gateway | `azurerm_virtual_network_gateway` (ER) | `azurerm_express_route_gateway` (vHub) |
| Firewall | `azurerm_firewall` (in hub VNet) | `azurerm_firewall` associated to secured vHub |
| Branch Site | N/A (manual config) | `azurerm_vpn_site` + connection |
| Route Control | `azurerm_route_table`, UDRs | vHub route tables + connection routing intents |

## 15. Summary Recommendation (For an AKS Learning/Foundational Repo)
If you are primarily single-region and experimenting: hub-and-spoke remains simpler to reason about and showcases core Azure networking primitives. As you progress toward multi-region, multi-branch, or need unified remote user + site connectivity, plan an evolutionary path to Virtual WAN, converting the existing hub into a shared-services spoke.

## 16. Quick Decision Flow
```
Need bespoke NVAs / host services in hub? --> Hub-and-Spoke
Multi-region + many branches/users coming? --> Virtual WAN
Heavy custom traffic engineering?          --> Hub-and-Spoke
Desire faster global rollout / less ops?   --> Virtual WAN
Hybrid constraints?                        --> Mixed (vWAN + legacy hub as spoke)
```

## 17. References (Microsoft Learn)
1. What is Azure Virtual WAN?  https://learn.microsoft.com/azure/virtual-wan/virtual-wan-about
2. Virtual WAN FAQ  https://learn.microsoft.com/azure/virtual-wan/virtual-wan-faq
3. Virtual WAN network topology  https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/virtual-wan-network-topology
4. Hub-and-spoke topology (CAF)  https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/hub-spoke-network-topology
5. Patterns for inter-spoke networking  https://learn.microsoft.com/azure/architecture/networking/guide/spoke-to-spoke-networking
6. Azure Private Link in hub-and-spoke  https://learn.microsoft.com/azure/architecture/networking/guide/private-link-hub-spoke-network
7. Migrate to Azure Virtual WAN  https://learn.microsoft.com/azure/virtual-wan/migrate-from-hub-spoke-topology

> All comparisons grounded in the referenced Microsoft documentation (retrieved 2025-09-01). Always re-verify limits & feature support as Azure services evolve.

---
Feel free to open an issue or PR to extend this with concrete Terraform code snippets if/when you adopt vWAN in this repository.
