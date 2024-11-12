# databricks-tools
## This folder has a collection of tools I use for databricks related projects or tasks
### Terraform Azure VNet Injection Back End Private Link with UC Metastore creation 
#### adb-vnet-injection-backend-pl-uc  is the folder
This Terraform folder is based on [Databricks Terraform examples](https://github.com/databricks/terraform-databricks-examples/tree/main/examples/adb-with-private-link-standard) but without Front End Private Link.  This latest addition also enables [Default Workspace Storage Firewall (Private DBFS)](https://learn.microsoft.com/en-us/azure/databricks/security/network/storage/firewall-support). The template will create all the resources needed to deploy databricks in Azure
1. Modify the env.tfas file to change resource names
2. I added tagging in main.tf and dbfs.tf to ensure the Resource Group gets an owner and Dont remove before date.  You may want to change these as well so they don't have my name / email
3. Perform an az login with an account that has Owner  or Network Administrator privileges
4. From the main directory execute a Plan and if successful run apply
* terraform plan -var-file="env.tfvars"
* terraform apply -var-file="env.tfvars"
#### Azure Storage Firewall Databricks VNets
Serverless clusters need access to your storage accounts.  VNet Whitelisting using Azure Storage Firewall is the simplest option.  Private Link is an option not covered in these scripts.  Refer to our [documentation](https://learn.microsoft.com/en-us/azure/databricks/security/network/serverless-network-security/serverless-private-link) for additional information 
Once the new storage account is created, we will run AZ CLI commands to add all the Databricks VNets to the storage firewall. You will need to run the script for each storage account serverless needs to access
<p>
Clone or copy my [github databricks-tools repo](https://github.com/ScottGriz/databricks-tools)
</p>
<p>
Navigate to the /azure-storage-fw directory
</p>
<p>I am assuming you have access to a linux VM or MAC:you may have to add execute permissions to the .sh files </p>
<b>$ chmod u+x *.sh</b>
<p>
You can modify my BASH script "create-storage-fw-rules-params.sh" to perform the operation.  The only value that needs to be changed in the file is the subscription ID, the rest are command line options. You will need to create a new file for your region and all the databricks VNet Resource IDs.  
</p>  
<p>Log into your accounts.azuredatabricks.net portal => Cloud resources,  Search for your NCC assigned to the workspace and open the NCC.  Click on "Default Rules" => View All.  Copy all the resource IDs and make a file such as databricks-rules.txt. 
</p>
<p>Ensure azure CLI is installed on the machine you are running and your user has the appropriate permissions (Usually contributor to the storage account and network operator). Then execute the shell script ./create-storage-fw-rules-params.sh</p>

<b>az login<b>
<p>
<b>./create-storage-fw-rules-params.sh databricks-rules.txt "YOUR_RESOURCE_GROUP" "YOUR_STORAGE_ACCOUNT_NAME"</b>
</p>

#### Sample Data Folder
This folder contains sample data that can be used for privacy functions
