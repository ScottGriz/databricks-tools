resource "azurerm_resource_group" "resourcegroup" {
  name     = var.resource_group_name
  location = var.location
  tags = local.tags
}

resource "azurerm_virtual_network" "vnet_for_databricks" {
  name = "${var.prefix}-vnet"
  location = var.location
  resource_group_name = azurerm_resource_group.resourcegroup.name
  address_space = [var.cidr]
  tags = local.tags
}

resource "azurerm_network_security_group" "nsg_for_databricks" {
  name                = "${var.prefix}-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.resourcegroup.name
  tags                = local.tags
}

resource "azurerm_network_security_rule" "aad" {
  name                        = "AllowAAD"
  priority                    = 200
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "AzureActiveDirectory"
  resource_group_name         = azurerm_resource_group.resourcegroup.name
  network_security_group_name = azurerm_network_security_group.nsg_for_databricks.name
}

resource "azurerm_network_security_rule" "azfrontdoor" {
  name                        = "AllowAzureFrontDoor"
  priority                    = 201
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "AzureFrontDoor.Frontend"
  resource_group_name         = azurerm_resource_group.resourcegroup.name
  network_security_group_name = azurerm_network_security_group.nsg_for_databricks.name
}

resource "azurerm_subnet" "public" {
  name                 = "${var.prefix}-public"
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  virtual_network_name = azurerm_virtual_network.vnet_for_databricks.name
  address_prefixes     = [cidrsubnet(var.cidr, 3, 0)]

  delegation {
    name = "databricks"
    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
      "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"]
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "public" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.nsg_for_databricks.id
}

variable "private_subnet_endpoints" {
  default = []
}

resource "azurerm_subnet" "private" {
  name                 = "${var.prefix}-private"
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  virtual_network_name = azurerm_virtual_network.vnet_for_databricks.name
  address_prefixes     = [cidrsubnet(var.cidr, 3, 1)]

  delegation {
    name = "databricks"
    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
      "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"]
    }
  }

  service_endpoints = var.private_subnet_endpoints
}

resource "azurerm_subnet_network_security_group_association" "private" {  
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.nsg_for_databricks.id
}

resource "azurerm_subnet" "plsubnet" {
  name                                           = "${var.prefix}-privatelink"
  resource_group_name                            = azurerm_resource_group.resourcegroup.name
  virtual_network_name                           = azurerm_virtual_network.vnet_for_databricks.name
  address_prefixes                               = [cidrsubnet(var.cidr, 3, 2)]
}

# Workspace definition
resource "azurerm_databricks_workspace" "this" {
  name                          = var.databricks_workspace_name
  resource_group_name           = resource.azurerm_resource_group.resourcegroup.name
  managed_resource_group_name   = var.managed_rg
  location                      = var.location
  sku                           = "premium"
  public_network_access_enabled = true // no front end privatelink deployment
  network_security_group_rules_required = "NoAzureDatabricksRules"
  customer_managed_key_enabled = false # TODO for more secure deployment
  default_storage_firewall_enabled = true
  access_connector_id = azurerm_databricks_access_connector.dbfs.id
  tags  = local.tags
  custom_parameters {
    no_public_ip             = true
    storage_account_name     = var.ws_managed_storage_account_name
    storage_account_sku_name = "Standard_LRS"
    virtual_network_id = azurerm_virtual_network.vnet_for_databricks.id
    private_subnet_name = azurerm_subnet.private.name
    public_subnet_name = azurerm_subnet.public.name
    public_subnet_network_security_group_association_id = azurerm_subnet_network_security_group_association.public.id
    private_subnet_network_security_group_association_id = azurerm_subnet_network_security_group_association.private.id
  }
  depends_on = [
    azurerm_subnet_network_security_group_association.private,
    azurerm_subnet_network_security_group_association.public
  ]
}

# Private Endpoint definitions
resource "azurerm_private_dns_zone" "dnsuiapi" {
  name                = "privatelink.azuredatabricks.net"
  resource_group_name = azurerm_resource_group.resourcegroup.name
}

resource "azurerm_private_endpoint" "uiapi" {
  name                = "uiapipvtendpoint"
  location            = var.location
  resource_group_name = azurerm_resource_group.resourcegroup.name
  subnet_id           = azurerm_subnet.plsubnet.id

  private_service_connection {
    name                           = "ple-${var.databricks_workspace_name}-uiapi-pep"
    private_connection_resource_id = azurerm_databricks_workspace.this.id
    is_manual_connection           = false
    subresource_names              = ["databricks_ui_api"]
  }

  private_dns_zone_group {
    name                 = "private-dns-zone-uiapi"
    private_dns_zone_ids = [azurerm_private_dns_zone.dnsuiapi.id]
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "uiapidnszonevnetlink" {
  name                  = "uiapispokevnetconnection"
  resource_group_name   = azurerm_resource_group.resourcegroup.name
  private_dns_zone_name = azurerm_private_dns_zone.dnsuiapi.name
  virtual_network_id    = azurerm_virtual_network.vnet_for_databricks.id // connect to spoke vnet
}

# Assign the newly created workspace to an existing metastore in the same region
resource "databricks_metastore_assignment" "this" {
  workspace_id         = azurerm_databricks_workspace.this.workspace_id
  metastore_id         = var.metastore_id
  default_catalog_name = "main"
}

