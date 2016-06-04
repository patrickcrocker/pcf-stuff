#!/bin/bash
#
# Pivotal Network Product Tile Download Script
#
# This script is intended to be run from the Ops Manager VM to download a Pivotal 
# product file.  Before running this script you must accept the End User License Agreement.
# This is done by logging into Pivnet and downloading the product which will prompt 
# you to accept the EULA.  After you have agreed, you can cancel the download and 
# then use this script!
#
# You'll need your Pivnet API token which can be found on the 'Edit Profile' page 
# on Pivnet.  For convenience, you can export this as an environment variable:
# $ export PIVNET_TOKEN=<pivnetApiToken>
#
# Usage:
# $ ./pivnet-download.sh <pivnet-product-api-download-url>
#

set -e

if [ -z "$PIVNET_TOKEN" ]; then
  echo "Pivnet API Token: "
  read -r PIVNET_TOKEN
fi

if [ -z "$1" ]; then
  echo "Remote file URL: "
  read -r DOWNLOAD_URL
else
  DOWNLOAD_URL=$1
fi

# Get the filename from the redirect
FILENAME=$(curl -s --data '' -D- -o /dev/null -H "Authorization: Token $PIVNET_TOKEN" $DOWNLOAD_URL | grep -o -E 'filename=.*$' | sed -e 's/filename=//' | sed 's/\r$//')

echo "Downloading $FILENAME from $DOWNLOAD_URL"

curl -o $FILENAME \
  -L --data '' \
  -H "Authorization: Token $PIVNET_TOKEN" \
  $DOWNLOAD_URL
