terraform {
  required_providers {
    databricks = {
      source = "databricks/databricks"
      version = "1.14.0"
    }
  }
}

data "azurerm_databricks_workspace" "this" {
  name                = var.databricks_workspace_name # from /basic-env/azure_infra_tf/optional_external_storage_tf/variables.tf
  resource_group_name = var.resource_group_name
}

data "azurerm_resource_group" "this" {
    name = var.resource_group_name
}

#commented out because arthur 
# resource "azurerm_role_assignment" "sp_assignment" {
#     scope = azurerm_resource_group.this.id
#     role_definition_name = "Contibutor"
#     principal_id = var.service_principal_application_id
# }

resource "azurerm_storage_account" "external_storage_account" {
  # configs for a RA GRS storage
  name                     = var.ext_storage_account_name # Gonna need randomization function here or a tfvar
  location                 = var.location
  resource_group_name      = var.resource_group_name
  account_tier             = var.storage_account_tier
  account_replication_type = "RAGRS"
  is_hns_enabled           = true # Enabling hierarchical namespace for ADLS Gen 2
}

resource "azurerm_storage_container" "location_to_mount" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.external_storage_account.name
  container_access_type = "private"
}

# resource "databricks_service_principal" "sp_temp" {
#     display_name = "Automation-only SP"
#     application_id = var.service_principal_application_id
# }

# it works only with AAD token!
provider "databricks" {
  host = data.azurerm_databricks_workspace.this.workspace_url
  azure_workspace_resource_id = data.azurerm_databricks_workspace.this.id
  azure_client_id = var.service_principal_application_id
  azure_client_secret = var.service_principal_application_secret
  azure_tenant_id = var.tenant_id
}


# resource "databricks_permissions" "token_usage" {
#     authorization = "tokens"
#     access_control {
#        service_principal_name = databricks_service_principal.sp_temp.application_id
#        permission_level = "CAN_USE"
#     }
# }

resource "databricks_token" "patrick" {
    comment = "PAT on behalf of the service principal"
    lifetime_seconds = 10000
}



data "databricks_node_type" "smallest" {
  local_disk = true
}

data "databricks_spark_version" "latest" {
}

# TODO: Need to automatically delegate Service Principal as Storage Blob Data Contributor to the storage account

resource "databricks_cluster" "shared_passthrough" {
  cluster_name            = "Shared Passthrough for mount"
  spark_version           = data.databricks_spark_version.latest.id
  node_type_id            = data.databricks_node_type.smallest.id
  autotermination_minutes = 10
  num_workers             = 1

  spark_conf = {
    "spark.databricks.cluster.profile" : "serverless",
    "spark.databricks.repl.allowedLanguages" : "python,sql",
    "spark.databricks.passthrough.enabled" : "true",
    "spark.databricks.pyspark.enableProcessIsolation" : "true"
  }

  custom_tags = {
    "ResourceClass" : "Serverless"
  }
}

resource "databricks_mount" "external_storage_mount_passthrough" {
    name = "tf-abfss"
    cluster_id = databricks_cluster.shared_passthrough.id
    uri = "abfss://${azurerm_storage_container.location_to_mount.name}@${azurerm_storage_account.external_storage_account.name}.dfs.core.windows.net"
    extra_configs = {
      "fs.azure.account.auth.type" = "CustomAccessToken",
      "fs.azure.account.custom.token.provider.class" : "{{sparkconf/spark.databricks.passthrough.adls.gen2.tokenProviderClassName}}",
    }
}


# Access connector for Azure Databricks for Unity Catalog

# One access connector in main region Access Connector Primary

# One access connector in secondary region Access Connector Secondary

# Assign permissions to both for the Storage Account, Storage Blob Data Connector