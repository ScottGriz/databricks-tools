locals {
  dbfs_resource_id = "${azurerm_databricks_workspace.this.managed_resource_group_id}/providers/Microsoft.Storage/storageAccounts/${azurerm_databricks_workspace.this.custom_parameters[0].storage_account_name}"
  tags = {
    Owner = "scott.grzybowski@databricks.com",
    RemoveAfter = "2026-12-31"
  }
}

# Access Connector needed for Private DBFS
resource "azurerm_databricks_access_connector" "dbfs" {
  name                = "${var.prefix}-databricks-mi"
  #Does this have to go in the MRG???
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = var.location
  identity {
    type = "SystemAssigned"
  }
  tags = local.tags
}

resource "azurerm_private_endpoint" "dfspe" {
  name                = "dbfs-dfs-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.resourcegroup.name
  subnet_id           = azurerm_subnet.plsubnet.id

  private_dns_zone_group {
    name = "add_to_azure_private_dns_dfs"
    private_dns_zone_ids = [azurerm_private_dns_zone.adlsstorage.id]
  }

  private_service_connection {
    name                           = "${var.prefix}-pl-dfs"
    private_connection_resource_id = local.dbfs_resource_id
    subresource_names              = ["dfs"]
    is_manual_connection = false
  }
}

resource "azurerm_private_endpoint" "blobpe" {
  name                = "dbfs-blob-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.resourcegroup.name
  subnet_id           = azurerm_subnet.plsubnet.id
  
    private_dns_zone_group {
    name = "add_to_azure_private_dns_blob"
    private_dns_zone_ids = [azurerm_private_dns_zone.blobstorage.id]
  }

  private_service_connection {
    name                           = "${var.prefix}-pl-blob"
    private_connection_resource_id = local.dbfs_resource_id
    subresource_names              = ["blob"]
    is_manual_connection = false
  }
}

resource "azurerm_private_dns_zone" "blobstorage" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.resourcegroup.name
}

resource "azurerm_private_dns_zone" "adlsstorage" {
  name                = "privatelink.dfs.core.windows.net"
  resource_group_name = azurerm_resource_group.resourcegroup.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dfszone" {
  name                  = "${var.prefix}-dfslink"
  resource_group_name   = azurerm_resource_group.resourcegroup.name
  private_dns_zone_name = azurerm_private_dns_zone.adlsstorage.name
  virtual_network_id    = azurerm_virtual_network.vnet_for_databricks.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "blobzone" {
  name                  = "${var.prefix}-bloblink"
  resource_group_name   = azurerm_resource_group.resourcegroup.name
  private_dns_zone_name = azurerm_private_dns_zone.blobstorage.name
  virtual_network_id    = azurerm_virtual_network.vnet_for_databricks.id
}