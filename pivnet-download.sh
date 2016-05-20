#!/bin/bash

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
