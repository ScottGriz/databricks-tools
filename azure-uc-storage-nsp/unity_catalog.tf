# ---------------------------------------------------------------------------
# Unity Catalog storage credential + external location.
#
# Created only after RBAC has propagated and the storage account is in the
# perimeter, so UC's validation exercises the real network and identity path.
# ---------------------------------------------------------------------------

resource "databricks_storage_credential" "this" {
  name            = var.storage_credential_name
  comment         = "Managed identity of ${azurerm_databricks_access_connector.this.name}"
  skip_validation = var.skip_validation

  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.this.id
  }

  depends_on = [time_sleep.rbac_propagation]
}

resource "databricks_external_location" "this" {
  name               = var.external_location_name
  url                = "abfss://${azurerm_storage_container.this.name}@${azurerm_storage_account.this.name}.dfs.core.windows.net/${var.external_location_path}"
  credential_name    = databricks_storage_credential.this.name
  enable_file_events = var.enable_file_events
  skip_validation    = var.skip_validation
  comment            = "ADLS Gen2 ${azurerm_storage_account.this.name}/${azurerm_storage_container.this.name} (NSP: ${var.nsp_name})"

  # Recent provider versions require a queue type whenever file events are on.
  # managed_aqs = "Automatic" mode: Databricks creates the Azure Storage Queue
  # and Event Grid subscription in this resource group, using the access
  # connector's file-events roles from rbac.tf.
  dynamic "file_event_queue" {
    for_each = var.enable_file_events ? [1] : []
    content {
      managed_aqs {
        resource_group  = local.rg_name
        subscription_id = var.subscription_id
      }
    }
  }

  depends_on = [
    time_sleep.rbac_propagation,
    azurerm_network_security_perimeter_association.storage,
    azurerm_network_security_perimeter_access_rule.databricks_serverless,
  ]

  lifecycle {
    precondition {
      condition     = !var.enable_file_events || var.allow_trusted_azure_services
      error_message = "File events require the storage firewall's 'Allow trusted Microsoft services' bypass. Set allow_trusted_azure_services = true or enable_file_events = false."
    }
  }
}
