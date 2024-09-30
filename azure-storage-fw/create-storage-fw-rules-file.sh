#!/bin/bash
input=$1
while IFS= read -r SUBNET
do
  echo "$SUBNET"
  az storage account network-rule add --subscription <YOURSUBSCRIPTION> --resource-group <YOURRG> --account-name <YOURACCOUNTNAME> --subnet "$SUBNET"
done < "$input"
