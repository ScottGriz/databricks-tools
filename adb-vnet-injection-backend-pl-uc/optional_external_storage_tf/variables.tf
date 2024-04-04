variable resource_group_name {
  description = "The name of the resource group in which to create the Databricks workspace."
  type        = string
}

variable databricks_workspace_name {
  description = "The name of the Databricks workspace."
  type        = string
}

variable ext_storage_account_name {
  description = "The name of the external storage account for our datalake."
  type        = string
}

variable location { 
  description = "The location/region where the Databricks workspace should be created."
  type        = string
}

variable storage_account_tier {
  description = "The access tier of the Databricks workspace."
  type        = string
}

variable storage_account_replication_type {
  description = "The replication type of the Databricks workspace."
  type        = string
}

variable container_name {
  description = "The container name in the storage account"
  type        = string
}

variable service_principal_application_id {
  description = "the service principal app id for this resource"
  type = string
}

variable service_principal_application_secret {
  description = "the service principal app secret for this resource"
  type = string
}

variable tenant_id {
  description = "the tenant of the resource"
  type = string
}