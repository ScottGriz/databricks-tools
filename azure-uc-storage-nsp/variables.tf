# ---------------------------------------------------------------------------
# Subscription and service principal login
# ---------------------------------------------------------------------------

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID to deploy into."
}

variable "tenant_id" {
  type        = string
  description = "Entra ID tenant ID of the service principal."
}

variable "client_id" {
  type        = string
  description = "Application (client) ID of the service principal Terraform logs in as."
}

variable "client_secret" {
  type        = string
  description = "Client secret of the service principal. Prefer TF_VAR_client_secret over tfvars."
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Resource group and region
# ---------------------------------------------------------------------------

variable "resource_group_name" {
  type        = string
  description = "Existing resource group for the Access Connector and storage account."
}

variable "location" {
  type        = string
  description = "Azure region for new resources. Defaults to the resource group's region. Must match the NSP's region."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all Azure resources."
  default     = {}
}

# ---------------------------------------------------------------------------
# Network security perimeter (existing)
# ---------------------------------------------------------------------------

variable "nsp_name" {
  type        = string
  description = "Name of the existing network security perimeter."
}

variable "nsp_resource_group_name" {
  type        = string
  description = "Resource group of the NSP. Defaults to resource_group_name."
  default     = null
}

variable "nsp_profile_name" {
  type        = string
  description = "NSP profile to associate the storage account with."
  default     = "defaultProfile"
}

variable "nsp_access_mode" {
  type        = string
  description = "NSP association access mode. Learning is the API name for the portal's Transition mode, which Databricks recommends."
  default     = "Learning"

  validation {
    condition     = contains(["Learning", "Audit", "Enforced"], var.nsp_access_mode)
    error_message = "nsp_access_mode must be Learning, Audit, or Enforced."
  }
}

variable "nsp_serverless_service_tags" {
  type        = list(string)
  description = "If non-empty, adds an inbound rule to the NSP profile for these service tags, e.g. [\"AzureDatabricksServerless.EastUS2\"]. Leave empty if the profile already has the rule."
  default     = []
}

# ---------------------------------------------------------------------------
# Access Connector and storage
# ---------------------------------------------------------------------------

variable "access_connector_name" {
  type        = string
  description = "Name of the new Access Connector for Azure Databricks."
}

variable "storage_account_name" {
  type        = string
  description = "Name of the new ADLS Gen2 storage account (3-24 lowercase letters and digits, globally unique)."

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name must be 3-24 lowercase letters and digits."
  }
}

variable "storage_replication_type" {
  type        = string
  description = "Storage account replication: LRS, ZRS, GRS, RAGRS, GZRS, or RAGZRS."
  default     = "ZRS"
}

variable "container_name" {
  type        = string
  description = "ADLS Gen2 container backing the external location."
  default     = "uc-external"
}

variable "allow_trusted_azure_services" {
  type        = bool
  description = "Set the storage firewall's 'Allow trusted Microsoft services' bypass. Required for file events. Turn off only if policy forbids it (and set enable_file_events = false); the NSP rule then carries serverless traffic."
  default     = true
}

variable "enable_file_events" {
  type        = bool
  description = "Grant the extra roles for UC managed file events and enable file events on the external location."
  default     = true
}

# ---------------------------------------------------------------------------
# Unity Catalog
# ---------------------------------------------------------------------------

variable "databricks_workspace_url" {
  type        = string
  description = "URL of a Unity Catalog-enabled workspace, e.g. https://adb-1234567890123456.7.azuredatabricks.net."
}

variable "storage_credential_name" {
  type        = string
  description = "Name of the UC storage credential."
}

variable "external_location_name" {
  type        = string
  description = "Name of the UC external location."
}

variable "external_location_path" {
  type        = string
  description = "Optional path inside the container for the external location (no leading slash). Empty = container root."
  default     = ""
}

variable "skip_validation" {
  type        = bool
  description = "Skip UC's access check when creating the credential and external location. Leave false so a broken network or RBAC path fails the apply."
  default     = false
}
