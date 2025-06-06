variable resource_group_name {
  description = "The name of the resource group in which to create the Databricks workspace."
  type        = string
}

variable databricks_workspace_name {
  description = "The name of the Databricks workspace."
  type        = string
}

variable managed_rg {
  description = "The name of the managed resource group in which to create the Databricks workspace."
  type        = string
}

variable ws_managed_storage_account_name {
  description = "The name of the storage account in which to create the Databricks workspace."
  type        = string
}

variable location { 
  description = "The location/region where the Databricks workspace should be created."
  type        = string
}

variable prefix {
  description = "Prefix for locations and other resources that are labeled consistenly for networking"
  type        = string
}

variable metastore_id {
  description = "Unique UUID for the UC Metastore - must be in the same region as the Workspace"
  type        = string
}

variable cidr {
  description = "The CIDR range for the network that we will be provisioning"
  type        = string
}