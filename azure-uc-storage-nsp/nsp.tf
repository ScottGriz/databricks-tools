# ---------------------------------------------------------------------------
# Network security perimeter (existing) — associate the storage account.
#
# Learning (Transition) mode evaluates NSP rules first, then falls back to the
# storage firewall. Databricks recommends staying in Transition: Enforced also
# blocks any other service the storage firewall allows that isn't in the NSP.
# ---------------------------------------------------------------------------

data "azurerm_network_security_perimeter" "this" {
  name                = var.nsp_name
  resource_group_name = coalesce(var.nsp_resource_group_name, var.resource_group_name)
}

data "azurerm_network_security_perimeter_profile" "this" {
  name                          = var.nsp_profile_name
  network_security_perimeter_id = data.azurerm_network_security_perimeter.this.id
}

resource "azurerm_network_security_perimeter_association" "storage" {
  name                                  = "${var.storage_account_name}-assoc"
  network_security_perimeter_profile_id = data.azurerm_network_security_perimeter_profile.this.id
  resource_id                           = azurerm_storage_account.this.id
  access_mode                           = var.nsp_access_mode

  lifecycle {
    # The AzureDatabricksServerless service tag only works for storage in the
    # workspace's region, and the NSP must be in that region too.
    precondition {
      condition     = lower(replace(data.azurerm_network_security_perimeter.this.location, " ", "")) == lower(replace(local.rg_location, " ", ""))
      error_message = "The NSP (${data.azurerm_network_security_perimeter.this.location}) must be in the same region as the storage account (${local.rg_location})."
    }
  }
}

# Optional: inbound rule for Databricks serverless. Skip if the profile
# already has one — rule names must be unique per profile.
resource "azurerm_network_security_perimeter_access_rule" "databricks_serverless" {
  count = length(var.nsp_serverless_service_tags) > 0 ? 1 : 0

  name                                  = "allow-databricks-serverless"
  network_security_perimeter_profile_id = data.azurerm_network_security_perimeter_profile.this.id
  direction                             = "Inbound"
  service_tags                          = var.nsp_serverless_service_tags
}
