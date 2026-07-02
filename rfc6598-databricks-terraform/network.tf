# ---------------------------------------------------------------------------
# Resource group (optionally created)
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "this" {
  count    = var.create_resource_group ? 1 : 0
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

data "azurerm_resource_group" "this" {
  count = var.create_resource_group ? 0 : 1
  name  = var.resource_group_name
}

locals {
  rg_name     = var.create_resource_group ? azurerm_resource_group.this[0].name : data.azurerm_resource_group.this[0].name
  rg_location = var.create_resource_group ? azurerm_resource_group.this[0].location : data.azurerm_resource_group.this[0].location
}

# ---------------------------------------------------------------------------
# RFC-6598 island VNet (non-routable) — hosts Databricks + supporting infra
# ---------------------------------------------------------------------------

resource "azurerm_virtual_network" "rfc6598" {
  name                = "griz-nonroute-vnet"
  resource_group_name = local.rg_name
  location            = local.rg_location
  address_space       = [var.rfc6598_vnet_cidr]
  tags                = var.tags
}

# NSG required on Databricks-delegated subnets (VNet injection requirement)
resource "azurerm_network_security_group" "databricks" {
  name                = "griz-dbx-nsg"
  resource_group_name = local.rg_name
  location            = local.rg_location
  tags                = var.tags
}

resource "azurerm_subnet" "dbx_public" {
  name                 = "public"
  resource_group_name  = local.rg_name
  virtual_network_name = azurerm_virtual_network.rfc6598.name
  address_prefixes     = [var.rfc6598_subnets.public]

  delegation {
    name = "databricks-del"
    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
      ]
    }
  }
}

resource "azurerm_subnet" "dbx_private" {
  name                 = "private"
  resource_group_name  = local.rg_name
  virtual_network_name = azurerm_virtual_network.rfc6598.name
  address_prefixes     = [var.rfc6598_subnets.private]

  delegation {
    name = "databricks-del"
    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
      ]
    }
  }
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "private-endpoints"
  resource_group_name  = local.rg_name
  virtual_network_name = azurerm_virtual_network.rfc6598.name
  address_prefixes     = [var.rfc6598_subnets.private_endpoints]
}

resource "azurerm_subnet" "utility" {
  name                 = "utility"
  resource_group_name  = local.rg_name
  virtual_network_name = azurerm_virtual_network.rfc6598.name
  address_prefixes     = [var.rfc6598_subnets.utility]
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = local.rg_name
  virtual_network_name = azurerm_virtual_network.rfc6598.name
  address_prefixes     = [var.rfc6598_subnets.bastion]
}

resource "azurerm_subnet_network_security_group_association" "dbx_public" {
  subnet_id                 = azurerm_subnet.dbx_public.id
  network_security_group_id = azurerm_network_security_group.databricks.id
}

resource "azurerm_subnet_network_security_group_association" "dbx_private" {
  subnet_id                 = azurerm_subnet.dbx_private.id
  network_security_group_id = azurerm_network_security_group.databricks.id
}

# ---------------------------------------------------------------------------
# Firewall 1 VNet (local SNAT / forced tunnel) — RFC-1918
# ---------------------------------------------------------------------------

resource "azurerm_virtual_network" "fw1" {
  name                = "griz-firewall1"
  resource_group_name = local.rg_name
  location            = local.rg_location
  address_space       = [var.firewall1_vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "fw1" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = local.rg_name
  virtual_network_name = azurerm_virtual_network.fw1.name
  address_prefixes     = [var.firewall1_subnets.fw_subnet]
}

resource "azurerm_subnet" "fw1_mgmt" {
  name                 = "AzureFirewallManagementSubnet"
  resource_group_name  = local.rg_name
  virtual_network_name = azurerm_virtual_network.fw1.name
  address_prefixes     = [var.firewall1_subnets.mgmt_subnet]
}

# ---------------------------------------------------------------------------
# Firewall 2 VNet (controlled egress) — RFC-1918
# ---------------------------------------------------------------------------

resource "azurerm_virtual_network" "fw2" {
  name                = "griz-firewall2"
  resource_group_name = local.rg_name
  location            = local.rg_location
  address_space       = [var.firewall2_vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "fw2" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = local.rg_name
  virtual_network_name = azurerm_virtual_network.fw2.name
  address_prefixes     = [var.firewall2_subnet]
}

# ---------------------------------------------------------------------------
# VNet peerings: RFC-6598 <-> FW1, and FW1 <-> FW2
# ---------------------------------------------------------------------------

resource "azurerm_virtual_network_peering" "rfc6598_to_fw1" {
  name                         = "rfc6598-to-fw1"
  resource_group_name          = local.rg_name
  virtual_network_name         = azurerm_virtual_network.rfc6598.name
  remote_virtual_network_id    = azurerm_virtual_network.fw1.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "fw1_to_rfc6598" {
  name                         = "fw1-to-rfc6598"
  resource_group_name          = local.rg_name
  virtual_network_name         = azurerm_virtual_network.fw1.name
  remote_virtual_network_id    = azurerm_virtual_network.rfc6598.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "fw1_to_fw2" {
  name                         = "fw1-to-fw2"
  resource_group_name          = local.rg_name
  virtual_network_name         = azurerm_virtual_network.fw1.name
  remote_virtual_network_id    = azurerm_virtual_network.fw2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "fw2_to_fw1" {
  name                         = "fw2-to-fw1"
  resource_group_name          = local.rg_name
  virtual_network_name         = azurerm_virtual_network.fw2.name
  remote_virtual_network_id    = azurerm_virtual_network.fw1.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
