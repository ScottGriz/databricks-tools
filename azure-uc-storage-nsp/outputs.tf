output "access_connector_id" {
  description = "Resource ID of the Access Connector."
  value       = azurerm_databricks_access_connector.this.id
}

output "access_connector_principal_id" {
  description = "Object ID of the Access Connector's managed identity."
  value       = local.access_connector_principal_id
}

output "storage_account_id" {
  description = "Resource ID of the storage account."
  value       = azurerm_storage_account.this.id
}

output "storage_dfs_endpoint" {
  description = "ADLS Gen2 (dfs) endpoint."
  value       = azurerm_storage_account.this.primary_dfs_endpoint
}

output "nsp_association_id" {
  description = "Resource ID of the NSP association."
  value       = azurerm_network_security_perimeter_association.storage.id
}

output "storage_credential_name" {
  description = "Unity Catalog storage credential."
  value       = databricks_storage_credential.this.name
}

output "external_location_name" {
  description = "Unity Catalog external location."
  value       = databricks_external_location.this.name
}

output "external_location_url" {
  description = "abfss:// URL registered as the external location."
  value       = databricks_external_location.this.url
}
