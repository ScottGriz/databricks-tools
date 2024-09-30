#!/bin/bash
function createRules () {
	local fileName="$1"
	local resourceGroup="$2"
	local storageAccountName="$3"
	#Subscription ID is hard coded for Field Engineering
	local subscription="3f2e4d32-8e8d-46d6-82bc-5bb8d962328b"
 	cat "$fileName" | while IFS= read -r SUBNET
		do
  			echo "$SUBNET"
  			az storage account network-rule add --subscription "$subscription" --resource-group "$resourceGroup" --account-name "$storageAccountName" --subnet "$SUBNET"
		done
 echo "$1 , $2 , $3" 
}

if [ $# -lt 3 ]; then
  echo "You must specify a file name with all the resource IDs for the subnets, Resource Group and the name of the Storage Account IN THAT ORDER"
  exit 1
else
  echo "File name with resource ids: $1" 
  echo "Resource Group: $2"
  echo "storage account name: $3"
  echo "$1 will be processed for resource group $2 and Storage Account Name $3"
  createRules $1 $2 $3
fi
