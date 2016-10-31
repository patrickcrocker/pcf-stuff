#!/bin/bash

set -e

command -v jq >/dev/null 2>&1 || { echo "This script requires jq. Please install from: https://stedolan.github.io/jq/"; exit 1; }

# Unique resource group across your subscription
RESOURCE_GROUP=pcf18rc2
# South Central represent!  (but really, use what you want)
LOCATION=southcentralus
# Make this up, just make sure it is globally unique across Azure, between 3 and 24 characters in length, and contain only lowercase letters and numbers
STORAGE_NAME=boshabcdef0123456789
# Same rules as above. Later we append the storage acount index number, so leave room!
DEPLOYMENT_STORAGE_BASENAME=deployabcdef0123456789
# Number of additional storage accounts to create (see above!)
DEPLOYMENT_STORAGE_ACCOUNTS=3
# Your Azure subscription id
SUBSCRIPTION_ID=SAMPLE01-B1B1-5544-afbc-SAMPLE00d7f9
# Get this from: https://network.pivotal.io/products/ops-manager
OPS_MAN_IMAGE_URL=https://opsmanagerciimagestorage.blob.core.windows.net/system/Microsoft.Compute/Images/images/opsmanager-osDisk.2f2d3039-5d95-47b4-98aa-e722f55cc55f.vhd


# Create Resource Group

azure group create $RESOURCE_GROUP $LOCATION

# Create Network Resources

azure network nsg create $RESOURCE_GROUP pcf-nsg $LOCATION

azure network nsg rule create $RESOURCE_GROUP pcf-nsg internet-to-lb --protocol Tcp --priority 100 --destination-port-range '*'

azure network nsg create $RESOURCE_GROUP opsmgr-nsg $LOCATION

azure network nsg rule create $RESOURCE_GROUP opsmgr-nsg http --protocol Tcp --destination-port-range 80 --priority 100

azure network nsg rule create $RESOURCE_GROUP opsmgr-nsg https --protocol Tcp --destination-port-range 443 --priority 200

azure network nsg rule create $RESOURCE_GROUP opsmgr-nsg ssh --protocol Tcp --destination-port-range 22 --priority 300

azure network vnet create $RESOURCE_GROUP pcf-net $LOCATION --address-prefixes 10.0.0.0/16

azure network vnet subnet create $RESOURCE_GROUP pcf-net pcf --address-prefix 10.0.0.0/20

# Create BOSH Storage Account

azure storage account create $STORAGE_NAME --resource-group $RESOURCE_GROUP --sku-name LRS --kind Storage --subscription $SUBSCRIPTION_ID --location $LOCATION

export AZURE_STORAGE_CONNECTION_STRING=$(azure storage account connectionstring show $STORAGE_NAME --resource-group $RESOURCE_GROUP --json | jq -r '.string')

azure storage container create opsmanager
azure storage container create bosh
azure storage container create stemcell --permission blob
azure storage table create stemcells

# Create Deployment Storage Accounts

COUNTER=0
while (( $COUNTER < $DEPLOYMENT_STORAGE_ACCOUNTS )); do

  DEPLOYMENT_STORAGE_NAME=$DEPLOYMENT_STORAGE_BASENAME$COUNTER

  azure storage account create $DEPLOYMENT_STORAGE_NAME --resource-group $RESOURCE_GROUP --sku-name LRS --kind Storage --subscription $SUBSCRIPTION_ID --location $LOCATION

  DEPLOYMENT_STORAGE_CONNECTION_STRING=$(azure storage account connectionstring show $DEPLOYMENT_STORAGE_NAME --resource-group $RESOURCE_GROUP --json | jq -r '.string')

  azure storage container create opsmanager --connection-string "$DEPLOYMENT_STORAGE_CONNECTION_STRING"
  azure storage container create bosh --connection-string "$DEPLOYMENT_STORAGE_CONNECTION_STRING"
  azure storage container create stemcell --permission blob --connection-string "$DEPLOYMENT_STORAGE_CONNECTION_STRING"

  let COUNTER+=1
done

# Create a Load Balancer

azure network lb create $RESOURCE_GROUP pcf-lb $LOCATION

LB_PUBLIC_IP=$(azure network public-ip create $RESOURCE_GROUP pcf-lb-ip $LOCATION --allocation-method Static --json | jq -r '.ipAddress')

azure network lb frontend-ip create $RESOURCE_GROUP pcf-lb pcf-fe-ip --public-ip-name pcf-lb-ip

azure network lb probe create $RESOURCE_GROUP pcf-lb tcp80 --protocol Tcp --port 80

azure network lb address-pool create $RESOURCE_GROUP pcf-lb pcf-vms

azure network lb rule create $RESOURCE_GROUP pcf-lb http --protocol tcp --frontend-port 80 --backend-port 80

azure network lb rule create $RESOURCE_GROUP pcf-lb https --protocol tcp --frontend-port 443 --backend-port 443

azure network lb rule create $RESOURCE_GROUP pcf-lb diego-ssh --protocol tcp --frontend-port 2222 --backend-port 2222

echo "Manual Step!! Create DNS A Records for *.apps.DOMAIN.COM and *.system.DOMAIN.COM pointing to IP: $LB_PUBLIC_IP"

# Boot Ops Manager

azure storage blob copy start $OPS_MAN_IMAGE_URL opsmanager \
  --dest-connection-string $AZURE_STORAGE_CONNECTION_STRING \
  --dest-container opsmanager \
  --dest-blob image.vhd

while true; do
  status=$(azure storage blob copy show opsmanager image.vhd --json | jq -r '.copy.status')
  if [ "$status" = "pending" ]; then
    echo "Copy status: $status; sleeping 60 seconds"
    sleep 60
  else
    echo "Copy status: $status"
    break
  fi
done

OPS_MAN_IP=$(azure network public-ip create $RESOURCE_GROUP ops-manager-ip $LOCATION --allocation-method Static --json | jq -r '.ipAddress')
echo "Manual Step!! Create DNS A Record for opsmgr.DOMAIN.COM pointing to IP: $OPS_MAN_IP"

azure network nic create --subnet-vnet-name pcf-net --subnet-name pcf \
  --network-security-group-name opsmgr-nsg \
  --private-ip-address 10.0.0.5 --public-ip-name ops-manager-ip \
  $RESOURCE_GROUP ops-manager-nic $LOCATION

ssh-keygen -t rsa -f opsman -C ubuntu

azure vm create $RESOURCE_GROUP ops-mananger $LOCATION \
  Linux --nic-name ops-manager-nic \
  --os-disk-vhd https://$STORAGE_NAME.blob.core.windows.net/opsmanager/os_disk.vhd \
  --image-urn https://$STORAGE_NAME.blob.core.windows.net/opsmanager/image.vhd \
  --admin-username ubuntu --storage-account-name $STORAGE_NAME \
  --vm-size Standard_DS2_v2 --ssh-publickey-file opsman.pub


echo "Almost finished, just complete these manual steps:"
echo "- Create DNS A Records for *.apps.DOMAIN.COM and *.system.DOMAIN.COM pointing to IP: $LB_PUBLIC_IP"
echo "- Create DNS A Record for opsmgr.DOMAIN.COM pointing to IP: $OPS_MAN_IP"
echo ""
