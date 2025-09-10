# Optional Hub / External Private DNS / Custom DNS Refactor Plan

Commit context: Current state introduced external private DNS zone references and custom VNet DNS but made them mandatory in code paths. This plan makes all of: hub config, external (central) private DNS zones, and custom DNS servers optional while preserving default behavior and providing an alternate tfvars example.

## Goals
- Preserve default behavior (no breaking change for existing users).
- Support: 
  1. No hub at all.
  2. Optional hub (only if config provided).
  3. Local creation of private DNS zones (default path).
  4. Optional use of externally managed (hub/central) private DNS zones (mutually exclusive with local creation).
  5. Optional custom DNS servers for the VNet.
- Provide alternate `.tfvars` showing a minimal scenario (no hub, no custom DNS, local zones).
- Fix current FQDN output regression (using resource ID instead of zone name).

## High-Level Strategy
- Add boolean feature switches and rely on null/empty values instead of mandatory inputs.
- Conditionalize resources with `for_each = condition ? map : {}`.
- Centralize zone name / ID logic in locals for uniform consumption.
- Maintain current variable names where practical; add new ones for clarity.

## Variables (Add / Modify)
Add:
- `variable "create_private_dns_zones" { type = bool, default = true }`
- `variable "use_external_private_dns_zones" { type = bool, default = false }`
- Change `custom_dns_servers` from `string` → `list(string)` (default `[]`). (Skip separate enable flag; emptiness is the switch.)

Refine existing:
- Ensure `hub_vnet_config` default = `null` (if not already) and wrap all usages with null-safe checks.
- Keep `private_dns_config` (object) default `null`; only required when `use_external_private_dns_zones = true`.

Validation rules (in `variables.tf`):
- Mutual exclusion: `!(var.use_external_private_dns_zones && var.create_private_dns_zones == false)` → Actually enforce: `!(var.use_external_private_dns_zones && var.create_private_dns_zones)`.
- External requirement: `var.use_external_private_dns_zones ? var.private_dns_config != null : true`.
- External zones map non-empty: `var.use_external_private_dns_zones ? length(var.private_dns_config.private_dns_zone_name) > 0 : true`.
- DNS zones mode sanity: disallow both `create_private_dns_zones=false` and `use_external_private_dns_zones=false` (would leave endpoints without DNS). Provide clear error message.

## Locals Adjustments
Restore original local static map:
```
local.private_dns_zones = {
  key_vault    = "privatelink.vaultcore.azure.net"
  storage_blob = "privatelink.blob.core.windows.net"
  storage_file = "privatelink.file.core.windows.net"
  sql_database = "privatelink.database.windows.net"
}
```
Add external references map (only if external mode enabled):
```
local.external_private_dns_zone_refs = (
  var.use_external_private_dns_zones && var.private_dns_config != null
) ? {
  for k, zone_name in var.private_dns_config.private_dns_zone_name :
  k => {
    name = zone_name
    id   = "/subscriptions/${var.private_dns_config.subscription_id}/resourceGroups/${var.private_dns_config.resource_group}/providers/Microsoft.Network/privateDnsZones/${zone_name}"
  }
} : {}
```
Unified zone name helpers:
```
local.key_vault_zone_name = var.use_external_private_dns_zones ? local.external_private_dns_zone_refs["key_vault"].name : local.private_dns_zones["key_vault"]
```
(Repeat if explicit per service needed, or just reference maps directly in outputs.)

## Resource Conditioning
Private DNS Zones:
```
resource "azurerm_private_dns_zone" "main" {
  for_each = var.create_private_dns_zones ? local.private_dns_zones : {}
  name                = each.value
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "main" {
  for_each              = var.create_private_dns_zones ? local.private_dns_zones : {}
  name                  = "${each.key}-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.main[each.key].name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
}
```
Private Endpoint DNS zone IDs (pattern):
```
private_dns_zone_ids = var.use_external_private_dns_zones ? [local.external_private_dns_zone_refs["key_vault"].id] : [azurerm_private_dns_zone.main["key_vault"].id]
```
Storage endpoints revert to dynamic mapping (avoid hardcoding blob):
```
private_dns_zone_ids = var.use_external_private_dns_zones ? [local.external_private_dns_zone_refs[each.value.dns_zone].id] : [azurerm_private_dns_zone.main[each.value.dns_zone].id]
```

## VNet DNS Servers
```
dns_servers = length(var.custom_dns_servers) > 0 ? var.custom_dns_servers : null
```
(Verify provider tolerates `null`; fallback to `[]` if needed.)

## Outputs
Fix FQDN output:
```
app_kv_private_fqdns = { for a, kv_name in local.app_kv_name_map : a => "${kv_name}.${(var.use_external_private_dns_zones ? local.external_private_dns_zone_refs["key_vault"].name : local.private_dns_zones["key_vault"])}" }
```
Unified private DNS zones output (optional):
```
output "effective_private_dns_zones" {
  value = var.use_external_private_dns_zones ? var.private_dns_config.private_dns_zone_name : local.private_dns_zones
}
```
Mode output (diagnostic):
```
output "private_dns_mode" { value = var.use_external_private_dns_zones ? "external" : (var.create_private_dns_zones ? "local" : "none") }
```

## Alternate tfvars Files
Create `infra/terraform.no-hub-no-custom-dns.tfvars`:
- `hub_vnet_config = null`
- `create_private_dns_zones = true`
- `use_external_private_dns_zones = false`
- `custom_dns_servers = []`
(Plus minimal required existing variables already in primary tfvars.)

(Optional bonus) `infra/terraform.external-dns-and-hub.tfvars` (show advanced mode) — not strictly requested.

## Backward Compatibility
- Default path: existing `terraform.tfvars` unchanged → still creates local zones; no custom DNS if list empty.
- External mode only engaged when user sets `use_external_private_dns_zones = true` and provides `private_dns_config`.
- No drift introduced except correcting malformed FQDN output.

## Edge Cases
| Case | Handling |
|------|----------|
| Both create & external enabled | Validation error |
| Both disabled | Validation error (no DNS strategy) |
| Missing external config when external enabled | Validation error |
| Empty custom DNS list | Azure default DNS used |
| Single custom DNS server only | Accepted but recommend documenting redundancy |

## Implementation Order
1. Add new variables + validations (`variables.tf`).
2. Adjust `custom_dns_servers` type and update VNet resource.
3. Restore + add locals for DNS zones (remove commented old code cleanup later).
4. Conditionalize DNS zone & link resources.
5. Refactor private endpoints to use conditional IDs.
6. Fix outputs (FQDN + optional mode output).
7. Add alternate tfvars file.
8. `terraform fmt && terraform validate`.
9. Run plan (default) → confirm minimal diff.
10. Run plan with alternate tfvars → confirm correct resource graph.
11. Document brief summary (optional link from README / Infrastructure-Plan).

## Testing Checklist
- Default plan: no unwanted DNS or hub changes; FQDN output correct.
- Alternate tfvars: no hub peering resources; local DNS zones created.
- External scenario (manual test) if configured: no DNS zone resources created; endpoints use external IDs.
- Re-run plan after apply: no drift.

## Risks & Mitigations
- Risk: Null vs empty list in `dns_servers` may cause provider diff. Mitigate by checking provider docs—fallback to `[]` if drift occurs.
- Risk: Typos in zone key mapping. Mitigate via validation (optionally ensure keys superset of required set if you want strictness).
- Risk: Users set both toggles accidentally. Mitigation: explicit validation error.

## Follow-Up (Optional Enhancements)
- Add data source lookups for existing private DNS zones instead of constructing IDs manually (removes hardcoded subscription/rg string interpolation risk).
- Add module encapsulation for DNS mode switching.
- Add automated integration test using `terraform plan -detailed-exitcode` in CI for all modes.

---
Prepared: (date auto)
