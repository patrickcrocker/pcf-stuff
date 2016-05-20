#!/bin/bash

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
