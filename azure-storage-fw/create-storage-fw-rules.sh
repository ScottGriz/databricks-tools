#!/bin/bash
SUBNETS=(/subscriptions/31ef391b-7908-48ec-8c74-e432113b607b/resourceGroups/prod-westus2-snp-1-compute-2/providers/Microsoft.Network/virtualNetworks/prod-westus2-snp-1-compute-2/subnets/worker-subnet /subscriptions/56beece1-dbc8-40ca-8520-e1d514fb2ccc/resourceGroups/prod-westus2-snp-1-compute-9/providers/Microsoft.Network/virtualNetworks/prod-westus2-snp-1-compute-9/subnets/worker-subnet )
for SUBNET in "${SUBNETS[@]}"
do
  az storage account network-rule add --subscription <YOURSUBSCRIPTION> --resource-group scott-griz-rg --account-name <YOURACCOUNTNAME> --subnet ${SUBNET}
done