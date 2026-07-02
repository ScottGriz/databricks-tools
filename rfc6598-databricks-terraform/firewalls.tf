# ===========================================================================
# Public IPs
# ===========================================================================

resource "azurerm_public_ip" "fw1_data" {
  name                = "fw1-pip"
  resource_group_name = local.rg_name
  location            = local.rg_location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_public_ip" "fw1_mgmt" {
  name                = "fw1-mgmt-pip"
  resource_group_name = local.rg_name
  location            = local.rg_location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_public_ip" "fw2_data" {
  name                = "fw2-pip"
  resource_group_name = local.rg_name
  location            = local.rg_location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# ===========================================================================
# Firewall 1 — local SNAT + forced tunneling
# ===========================================================================

resource "azurerm_firewall_policy" "fw1" {
  name                = "fw1-policy"
  resource_group_name = local.rg_name
  location            = local.rg_location
  sku                 = var.firewall_tier
  tags                = var.tags

  # LOCAL SNAT: Azure Firewall does NOT SNAT traffic destined to its
  # "private ranges". Setting 255.255.255.255/32 means almost nothing is
  # treated as private, so the firewall SNATs effectively ALL traffic to its
  # own private IP. (Do NOT use 0.0.0.0/0 here — that marks every destination
  # as private and DISABLES SNAT, blackholing cluster traffic at FW2.)
  private_ip_ranges = ["255.255.255.255/32"]
}

# Pass-through: allow all traffic originating from the RFC-6598 range so it
# can be SNATed and forced-tunneled onward to FW2.
resource "azurerm_firewall_policy_rule_collection_group" "fw1_passthrough" {
  name               = "rfc6598-passthrough"
  firewall_policy_id = azurerm_firewall_policy.fw1.id
  priority           = 200

  network_rule_collection {
    name     = "rfc6598-passthrough"
    priority = 200
    action   = "Allow"

    rule {
      name                  = "allow-all-from-rfc6598"
      protocols             = ["TCP", "UDP"]
      source_addresses      = [var.rfc6598_vnet_cidr]
      destination_addresses = ["*"]
      destination_ports     = ["*"]
    }
  }
}

resource "azurerm_firewall" "fw1" {
  name                = "griz-fw1"
  resource_group_name = local.rg_name
  location            = local.rg_location
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall_tier
  firewall_policy_id  = azurerm_firewall_policy.fw1.id
  tags                = var.tags

  ip_configuration {
    name                 = "fw1-ipconfig"
    subnet_id            = azurerm_subnet.fw1.id
    public_ip_address_id = azurerm_public_ip.fw1_data.id
  }

  # Management IP config is required for forced tunneling.
  management_ip_configuration {
    name                 = "fw1-mgmt-ipconfig"
    subnet_id            = azurerm_subnet.fw1_mgmt.id
    public_ip_address_id = azurerm_public_ip.fw1_mgmt.id
  }

  depends_on = [azurerm_firewall_policy_rule_collection_group.fw1_passthrough]
}

# ===========================================================================
# Firewall 2 — controlled egress to internet / on-prem
# ===========================================================================

resource "azurerm_firewall_policy" "fw2" {
  name                = "fw2-policy"
  resource_group_name = local.rg_name
  location            = local.rg_location
  sku                 = var.firewall_tier
  tags                = var.tags
  # Default SNAT behavior: auto-SNAT public destinations to FW2's public IP.
}

resource "azurerm_firewall_policy_rule_collection_group" "fw2_egress" {
  name               = "dbx-egress"
  firewall_policy_id = azurerm_firewall_policy.fw2.id
  priority           = 200

  # Databricks PaaS dependencies. Sources include both the original RFC-6598
  # range and FW1's SNAT range (10.29.0.0/24) — traffic arrives at FW2 already
  # SNATed by FW1 to a 10.29.0.x source, so that range MUST be allowed.
  network_rule_collection {
    name     = "adb-network-rules"
    priority = 200
    action   = "Allow"

    rule {
      name                  = "adb-control-plane"
      protocols             = ["TCP"]
      source_addresses      = [var.rfc6598_vnet_cidr, var.firewall1_vnet_cidr]
      destination_addresses = ["AzureDatabricks"]
      destination_ports     = ["443"]
    }

    rule {
      name                  = "adb-storage"
      protocols             = ["TCP"]
      source_addresses      = [var.rfc6598_vnet_cidr, var.firewall1_vnet_cidr]
      destination_addresses = ["Storage"]
      destination_ports     = ["443"]
    }

    rule {
      name                  = "adb-sql-metastore"
      protocols             = ["TCP"]
      source_addresses      = [var.rfc6598_vnet_cidr, var.firewall1_vnet_cidr]
      destination_addresses = ["Sql"]
      destination_ports     = ["3306", "1433"]
    }

    rule {
      name                  = "adb-eventhub"
      protocols             = ["TCP"]
      source_addresses      = [var.rfc6598_vnet_cidr, var.firewall1_vnet_cidr]
      destination_addresses = ["EventHub"]
      destination_ports     = ["443", "9093"]
    }

    rule {
      name                  = "adb-aad-monitor"
      protocols             = ["TCP"]
      source_addresses      = [var.rfc6598_vnet_cidr, var.firewall1_vnet_cidr]
      destination_addresses = ["AzureActiveDirectory", "AzureMonitor"]
      destination_ports     = ["443"]
    }
  }

  # Optional general HTTPS egress (e.g. library/package installs, validation).
  application_rule_collection {
    name     = "adb-app-rules"
    priority = 300
    action   = "Allow"

    rule {
      name              = "allow-https-egress"
      source_addresses  = [var.rfc6598_vnet_cidr, var.firewall1_vnet_cidr]
      destination_fqdns = ["*"]
      protocols {
        type = "Https"
        port = 443
      }
      protocols {
        type = "Http"
        port = 80
      }
    }
  }
}

resource "azurerm_firewall" "fw2" {
  name                = "griz-fw2"
  resource_group_name = local.rg_name
  location            = local.rg_location
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall_tier
  firewall_policy_id  = azurerm_firewall_policy.fw2.id
  tags                = var.tags

  ip_configuration {
    name                 = "fw2-ipconfig"
    subnet_id            = azurerm_subnet.fw2.id
    public_ip_address_id = azurerm_public_ip.fw2_data.id
  }

  depends_on = [azurerm_firewall_policy_rule_collection_group.fw2_egress]
}

# ===========================================================================
# Route tables
# ===========================================================================

# Databricks subnets: send all non-local traffic to FW1 (local SNAT).
resource "azurerm_route_table" "databricks" {
  name                = "griz-dbx-rt"
  resource_group_name = local.rg_name
  location            = local.rg_location
  tags                = var.tags

  route {
    name                   = "to-firewall1"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.fw1.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "dbx_public" {
  subnet_id      = azurerm_subnet.dbx_public.id
  route_table_id = azurerm_route_table.databricks.id
}

resource "azurerm_subnet_route_table_association" "dbx_private" {
  subnet_id      = azurerm_subnet.dbx_private.id
  route_table_id = azurerm_route_table.databricks.id
}

# FW1 subnet: forced tunnel — send all egress on to FW2.
resource "azurerm_route_table" "fw1" {
  name                = "griz-fw1-rt"
  resource_group_name = local.rg_name
  location            = local.rg_location
  tags                = var.tags

  route {
    name                   = "fw1-to-fw2"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.fw2.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "fw1" {
  subnet_id      = azurerm_subnet.fw1.id
  route_table_id = azurerm_route_table.fw1.id
}
