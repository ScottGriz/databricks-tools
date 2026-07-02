output "workspace_url" {
  description = "Databricks workspace URL."
  value       = azurerm_databricks_workspace.this.workspace_url
}

output "workspace_id" {
  description = "Databricks workspace resource ID."
  value       = azurerm_databricks_workspace.this.id
}

output "firewall1_private_ip" {
  description = "FW1 (local SNAT) private IP — next hop for Databricks subnets."
  value       = azurerm_firewall.fw1.ip_configuration[0].private_ip_address
}

output "firewall2_private_ip" {
  description = "FW2 (egress) private IP — next hop for FW1 forced tunnel."
  value       = azurerm_firewall.fw2.ip_configuration[0].private_ip_address
}

output "egress_public_ip" {
  description = "FW2 public IP. `curl https://ipinfo.io/ip` from a cluster should return this value."
  value       = azurerm_public_ip.fw2_data.ip_address
}

output "validation_command" {
  description = "Run this in a Databricks notebook to validate egress."
  value       = "%sh\\ncurl https://ipinfo.io/ip   # expect: ${azurerm_public_ip.fw2_data.ip_address}"
}
