#!/bin/bash
#
# This script automates the "Launching an Ops Manager Director Instance on Azure"
# instructions found at:
#   http://docs.pivotal.io/pivotalcf/1-8/customizing/azure-om-deploy.html
#
# Usage:
# azure-om-deploy azure-config.json
#

set -e

script=$(basename "$0")
config=$1

if [ ! -f "$config" ]; then
  echo "Missing json config file."
  echo "Please see azure-om-deploy-sample.json for an example."
  echo "Usage:"
  echo "  $script azure-config.json"
  exit 1
fi

command -v jq >/dev/null 2>&1 || { echo "This script requires jq. Please install from: https://stedolan.github.io/jq/"; exit 1; }

# Unique resource group across your subscription
RESOURCE_GROUP=$(cat $config | jq -r .RESOURCE_GROUP)
# South Central represent!  (but really, use what you want)
LOCATION=$(cat $config | jq -r .LOCATION)
# Make this up, just make sure it is globally unique across Azure, between 3 and 24 characters in length, and contain only lowercase letters and numbers
STORAGE_NAME=$(cat $config | jq -r .STORAGE_NAME)
# Same rules as above. Later we append the storage acount index number, so leave room!
DEPLOYMENT_STORAGE_BASENAME=$(cat $config | jq -r .DEPLOYMENT_STORAGE_BASENAME)
# Number of additional storage accounts to create (see above!)
DEPLOYMENT_STORAGE_ACCOUNTS=$(cat $config | jq -r .DEPLOYMENT_STORAGE_ACCOUNTS)
# Your Azure subscription id
SUBSCRIPTION_ID=$(cat $config | jq -r .SUBSCRIPTION_ID)
# Get this from: https://network.pivotal.io/products/ops-manager
OPS_MAN_IMAGE_URL=$(cat $config | jq -r .OPS_MAN_IMAGE_URL)
# The name of your Ops Manager VM
OPS_MAN_VM_NAME=$(cat $config | jq -r .OPS_MAN_VM_NAME)
# Size in GB of Ops Manager OS disk
OPS_MAN_VM_OS_DISK_SIZE=$(cat $config | jq -r .OPS_MAN_VM_OS_DISK_SIZE)

# Validate
currentSubscriptionId=$(azure account list --json | jq -r '.[] | select(.isDefault == true) | .id')

if [ "${SUBSCRIPTION_ID}x" != "$currentSubscriptionId" ]; then
  echo "The Azure subscription id defined in your config does not match the current id."
  echo "  Defined subscription ID: $SUBSCRIPTION_ID"
  echo "  Current subscription ID: $currentSubscriptionId"
  echo "Verify your correct subscription ID and then Run 'azure account set $SUBSCRIPTION_ID'"
fi
exit 99
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

ssh-keygen -t rsa -f opsman -C ubuntu -q -N ""

azure vm create $RESOURCE_GROUP $OPS_MAN_VM_NAME $LOCATION \
  Linux --nic-name ops-manager-nic \
  --os-disk-vhd https://$STORAGE_NAME.blob.core.windows.net/opsmanager/os_disk.vhd \
  --image-urn https://$STORAGE_NAME.blob.core.windows.net/opsmanager/image.vhd \
  --admin-username ubuntu --storage-account-name $STORAGE_NAME \
  --vm-size Standard_DS2_v2 --ssh-publickey-file opsman.pub

azure vm deallocate $RESOURCE_GROUP $OPS_MAN_VM_NAME

azure vm set $RESOURCE_GROUP $OPS_MAN_VM_NAME --new-os-disk-size $OPS_MAN_VM_OS_DISK_SIZE

azure vm start $RESOURCE_GROUP $OPS_MAN_VM_NAME

echo "Almost finished, just complete these manual steps:"
echo "- Create DNS A Records for *.apps.DOMAIN.COM and *.system.DOMAIN.COM pointing to IP: $LB_PUBLIC_IP"
echo "- Create DNS A Record for opsmgr.DOMAIN.COM pointing to IP: $OPS_MAN_IP"
echo ""
