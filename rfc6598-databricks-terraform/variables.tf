variable "subscription_id" {
  type        = string
  description = "Azure subscription ID to deploy into."
}

variable "resource_group_name" {
  type        = string
  description = "Existing resource group to deploy all resources into."
  default     = "scott-griz-ip-conserve"
}

variable "location" {
  type        = string
  description = "Azure region."
  default     = "westus2"
}

variable "workspace_name" {
  type        = string
  description = "Name of the Databricks workspace."
  default     = "scott-griz-ip-conserve"
}

variable "create_resource_group" {
  type        = bool
  description = "Whether to create the resource group. Set false to use an existing one."
  default     = false
}

# ---------------------------------------------------------------------------
# Address space
# ---------------------------------------------------------------------------

variable "rfc6598_vnet_cidr" {
  type        = string
  description = "RFC-6598 (CGNAT) address space for the non-routable island VNet."
  default     = "100.64.0.0/16"
}

variable "rfc6598_subnets" {
  type = object({
    public            = string # Databricks host/container (delegated)
    private           = string # Databricks private (delegated)
    private_endpoints = string
    utility           = string
    bastion           = string
  })
  description = "Subnets carved from the RFC-6598 VNet."
  default = {
    public            = "100.64.0.0/24"
    private           = "100.64.1.0/24"
    private_endpoints = "100.64.253.0/24"
    utility           = "100.64.254.0/24"
    bastion           = "100.64.255.0/26"
  }
}

variable "firewall1_vnet_cidr" {
  type        = string
  description = "RFC-1918 address space for the local-SNAT firewall VNet."
  default     = "10.29.0.0/24"
}

variable "firewall1_subnets" {
  type = object({
    fw_subnet   = string # AzureFirewallSubnet
    mgmt_subnet = string # AzureFirewallManagementSubnet (forced tunneling)
  })
  default = {
    fw_subnet   = "10.29.0.0/26"
    mgmt_subnet = "10.29.0.64/26"
  }
}

variable "firewall2_vnet_cidr" {
  type        = string
  description = "RFC-1918 address space for the egress firewall VNet."
  default     = "10.30.0.0/24"
}

variable "firewall2_subnet" {
  type        = string
  description = "AzureFirewallSubnet for the egress firewall."
  default     = "10.30.0.0/26"
}

variable "firewall_tier" {
  type        = string
  description = "Azure Firewall SKU tier (Standard or Premium)."
  default     = "Standard"
  validation {
    condition     = contains(["Standard", "Premium"], var.firewall_tier)
    error_message = "firewall_tier must be Standard or Premium."
  }
}

variable "databricks_sku" {
  type        = string
  description = "Databricks workspace SKU."
  default     = "premium"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources."
  default = {
    project = "rfc6598-ip-conservation"
    owner   = "scott.grzybowski"
  }
}
