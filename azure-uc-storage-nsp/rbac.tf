# ---------------------------------------------------------------------------
# Role assignments for the Access Connector's managed identity.
#
# Storage Blob Data Contributor is required for UC to read and write data.
# The other three are only needed for UC managed file events (auto-created
# Event Grid subscription + storage queue).
# ---------------------------------------------------------------------------

locals {
  access_connector_principal_id = azurerm_databricks_access_connector.this.identity[0].principal_id

  file_events_roles = var.enable_file_events ? {
    storage_account_contributor = {
      role  = "Storage Account Contributor"
      scope = azurerm_storage_account.this.id
    }
    storage_queue_data_contributor = {
      role  = "Storage Queue Data Contributor"
      scope = azurerm_storage_account.this.id
    }
    eventgrid_eventsubscription_contributor = {
      role  = "EventGrid EventSubscription Contributor"
      scope = data.azurerm_resource_group.this.id
    }
  } : {}
}

resource "azurerm_role_assignment" "blob_data_contributor" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = local.access_connector_principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "file_events" {
  for_each = local.file_events_roles

  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = local.access_connector_principal_id
  principal_type       = "ServicePrincipal"
}

# RBAC takes a minute or two to propagate; without this wait, UC validation
# of the new credential and external location fails intermittently.
resource "time_sleep" "rbac_propagation" {
  create_duration = "120s"

  # Re-run the wait whenever a role assignment is added or replaced, not only
  # on the first apply.
  triggers = {
    role_assignment_ids = join(",", concat(
      [azurerm_role_assignment.blob_data_contributor.id],
      [for k in sort(keys(azurerm_role_assignment.file_events)) : azurerm_role_assignment.file_events[k].id],
    ))
  }

  depends_on = [
    azurerm_role_assignment.blob_data_contributor,
    azurerm_role_assignment.file_events,
  ]
}
