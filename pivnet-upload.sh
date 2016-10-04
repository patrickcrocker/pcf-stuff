#!/bin/bash
#
# Pivotal Network Product Tile Upload-to-Ops-Manager Script
#
# This script is intended to be run from the Ops Manager VM to upload a local .pivotal 
# product file.  This script needs a UAA access token for authentication.
#
# To install the client run (this is probably already installed):
# $ gem install cf-uaac 
#
# Use the client to target UAA and generate a token:
# $ uaac target https://localhost/uaa --skip-ssl-validation
# $ uaac token owner get
#   Client name: opsman
#   Client secret: <empty>
#   User name: <opsMgrUserName>
#   Password: <opsMgrPassword>
#
# Export UAA access token variable:
# $ export UAA_ACCESS_TOKEN=$(uaac context <opsMgrUserName> | grep access_token | awk '{ print $2 }')
#
# If UAAC isn't available use the following KB to try CURL:
# *Use at your own risk!*
# https://discuss.pivotal.io/hc/en-us/articles/219118768
# 
# Usage:
# $ ./pivnet-upload.sh <p-some-tile-1.0.0.pivotal>
#

set -e

error_and_exit() {
  echo $1 >&2
  exit 1
}

if [ -z "$UAA_ACCESS_TOKEN" ]; then
  echo "UAA Access Token: "
  read -r UAA_ACCESS_TOKEN
fi

if [ -z "$1" ]; then
  echo "Local file name: "
  read -r LOCAL_FILE_NAME
else
  LOCAL_FILE_NAME=$1
fi

if [ ! -f "$LOCAL_FILE_NAME" ]; then
  error_and_exit "Invalid file: $LOCAL_FILE_NAME"
fi

curl "https://localhost/api/v0/available_products" \
  -k -# -o /dev/null \
  -X POST \
  -H "Authorization: Bearer $UAA_ACCESS_TOKEN" \
  -F "product[file]=@$LOCAL_FILE_NAME"
