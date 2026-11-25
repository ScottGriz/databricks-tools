terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.40"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.90"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

# ---------------------------------------------------------------------------
# Azure — authenticates as the service principal.
#
# The storage account has public network access disabled and shared-key auth
# off, so the provider must (1) use Entra ID for storage and (2) never call
# the storage data plane from wherever Terraform runs. data_plane_available =
# false forces containers to be managed through ARM (storage_account_id).
# ---------------------------------------------------------------------------

provider "azurerm" {
  features {
    storage {
      data_plane_available = false
    }
  }

  subscription_id     = var.subscription_id
  tenant_id           = var.tenant_id
  client_id           = var.client_id
  client_secret       = var.client_secret
  storage_use_azuread = true
}

# ---------------------------------------------------------------------------
# Databricks workspace — same service principal (Entra ID auth). The SP must
# be added to the workspace and hold the metastore privileges listed in the
# README.
# ---------------------------------------------------------------------------

provider "databricks" {
  host                = var.databricks_workspace_url
  azure_tenant_id     = var.tenant_id
  azure_client_id     = var.client_id
  azure_client_secret = var.client_secret
}
