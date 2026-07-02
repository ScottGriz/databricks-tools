# ---------------------------------------------------------------------------
# VNet-injected Databricks workspace in the RFC-6598 island network.
#
# Depends on the full firewall/route path being in place, otherwise clusters
# cannot reach the control plane and the workspace is non-functional.
# ---------------------------------------------------------------------------

resource "azurerm_databricks_workspace" "this" {
  name                        = var.workspace_name
  resource_group_name         = local.rg_name
  location                    = local.rg_location
  sku                         = var.databricks_sku
  managed_resource_group_name = "databricks-rg-${var.workspace_name}"
  tags                        = var.tags

  custom_parameters {
    virtual_network_id                                   = azurerm_virtual_network.rfc6598.id
    public_subnet_name                                   = azurerm_subnet.dbx_public.name
    private_subnet_name                                  = azurerm_subnet.dbx_private.name
    public_subnet_network_security_group_association_id  = azurerm_subnet_network_security_group_association.dbx_public.id
    private_subnet_network_security_group_association_id = azurerm_subnet_network_security_group_association.dbx_private.id
    no_public_ip                                         = true
  }

  # Ensure the egress path exists before the workspace, so cluster launches
  # have a working route to the control plane.
  depends_on = [
    azurerm_subnet_route_table_association.dbx_public,
    azurerm_subnet_route_table_association.dbx_private,
    azurerm_subnet_route_table_association.fw1,
    azurerm_firewall.fw2,
  ]
}
