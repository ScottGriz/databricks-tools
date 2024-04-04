resource_group_name="scott-griz-rg-pe"
databricks_workspace_name="scott-griz-tf-vnet-pl-ws"
managed_rg="scott-griz-mrg-pe"
ws_managed_storage_account_name="scottgriztfmdsa"
location="westus2"
prefix="scott-griz-tf-westus2"
cidr="172.32.0.0/24"

#terraform apply -var-file="env.tfvars"