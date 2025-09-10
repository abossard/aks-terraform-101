# Hub-less / No Custom DNS Scenario
# Uses locally created private DNS zones, no hub peering, Azure default DNS.

environment   = "dev"
project       = "aks102"
location      = "Sweden Central"
location_code = "sc"

vnet_address_space = "10.32.0.0/16"
pod_cidr           = "10.200.0.0/16"
service_cidr       = "172.16.0.0/16"
dns_service_ip     = "172.16.0.10"

kubernetes_version = "1.31.9"

sql_admin_username = "sqladmin"

app_namespace       = "aks-app"
app_service_account = "workload-identity-sa"

enable_container_registry = true
enable_secret_rotation    = true
secret_rotation_interval  = "2m"

enable_private_cluster = false

tags = {
  managedby          = "terraform"
}

clusters = {
  public = {
    name_suffix  = "public"
    subnet_cidr  = "10.32.0.0/24"
    min_count    = 1
    max_count    = 3
    vm_size      = "Standard_D2s_v3"
    applications = ["app1", "app2"]
  }
  private = {
    name_suffix  = "private"
    subnet_cidr  = "10.32.4.0/24"
    min_count    = 1
    max_count    = 2
    vm_size      = "Standard_D2s_v3"
    applications = ["api1", "api2"]
  }
}

# Hub-less
enable_vnet_peering          = false
hub_vnet_config              = null
vnet_peering_name            = null

# Local Private DNS Zones
create_private_dns_zones       = true
use_external_private_dns_zones = false
# No external private_dns_config provided.

# Azure default DNS (empty list)
custom_dns_servers = []

# SQL
sqldb_sku_name       = "S1"
sqldb_zone_redundant = false

stb_backup_interval_hour = "12"
stb_days_of_retention    = "14"

ltr_weekly_retention  = "P2W"
ltr_monthly_retention = "PT0S"
ltr_yearly_retention  = "PT0S"
ltr_week_of_year      = 1

ltr_immutable_backups_enabled = false

storage_replication_type = "LRS"
enable_backup = false
