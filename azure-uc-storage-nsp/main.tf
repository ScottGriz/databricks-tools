# ---------------------------------------------------------------------------
# Resource group (existing)
# ---------------------------------------------------------------------------

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

locals {
  rg_name     = data.azurerm_resource_group.this.name
  rg_location = coalesce(var.location, data.azurerm_resource_group.this.location)
}

# ---------------------------------------------------------------------------
# Access Connector for Azure Databricks — its system-assigned managed
# identity is what Unity Catalog uses to reach the storage account.
# ---------------------------------------------------------------------------

resource "azurerm_databricks_access_connector" "this" {
  name                = var.access_connector_name
  resource_group_name = local.rg_name
  location            = local.rg_location
  tags                = var.tags

  identity {
    type = "SystemAssigned"
  }
}

# ---------------------------------------------------------------------------
# ADLS Gen2 storage account — public network access disabled.
#
# Shared-key auth is off: UC authenticates with the Access Connector's
# managed identity (OAuth), so keys are never needed.
# ---------------------------------------------------------------------------

resource "azurerm_storage_account" "this" {
  name                     = var.storage_account_name
  resource_group_name      = local.rg_name
  location                 = local.rg_location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = var.storage_replication_type
  is_hns_enabled           = true
  tags                     = var.tags

  public_network_access_enabled   = false
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"

  # Set the bypass in the same ARM call that disables public access. The
  # property persists and is still enforced in Disabled mode, even though the
  # portal greys out the checkbox there.
  network_rules {
    default_action = "Deny"
    bypass         = var.allow_trusted_azure_services ? ["AzureServices"] : ["None"]
  }
}

# Created through ARM (storage_account_id), not the blob endpoint, because the
# data plane is unreachable from outside the perimeter.
resource "azurerm_storage_container" "this" {
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}
