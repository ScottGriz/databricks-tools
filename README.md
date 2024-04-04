# databricks-tools
## This folder has a collection of tools I use for databricks related projects or tasks
### Terraform Azure VNet Injection Back End Private Link with UC Metastore creation 
#### adb-vnet-injection-backend-pl-uc  is the folder
This Terraform folder is based on [Databricks Terraform examples](https://github.com/databricks/terraform-databricks-examples/tree/main/examples/adb-with-private-link-standard) but without Front End Private Link.  The template will create all the resources needed to deploy databricks in Azure
1. Modify the env.tfas file to change resource names
2. I added tagging in main.tf to ensure the Resource Group gets an owner and Dont remove before date.  You may want to change these as well so they don't have my name
3. Perform an az login with an account that has Owner  or Network Administrator privileges
4. From the main directory execute a Plan and if successful run apply
* terraform plan -var-file="env.tfvars"
* terraform apply -var-file="env.tfvars"
