#!/bin/bash

PIVNETRC=~/.pivnetrc

if [ -f "$PIVNETRC" ]; then
  chmod 400 $PIVNETRC
  source $PIVNETRC 2>/dev/null
fi

set -e

usage_and_exit() {
  cat <<EOF
Usage: pivnet <command> [options]
Examples:
  pivnet token SAMPLEaJimQVTq2zWBYZ
  pivnet download https://network.pivotal.io/.../product_files/7509/download
EOF
  exit 1
}

error_and_exit() {
  echo "$1" && exit 1
}

set_token() {
  [ -f "$PIVNETRC" ] && chmod 600 $PIVNETRC
  echo "PIVNET_API_TOKEN=$1" > $HOME/.pivnetrc
  chmod 400 $PIVNETRC
  echo "Updated Pivotal Network API Token"
}

download_from_pivnet() {
  local PIVNET_API_TOKEN=$PIVNET_API_TOKEN
  if [ -z "$PIVNET_API_TOKEN" ]; then
    read -r -p "Pivnet API Token: " PIVNET_API_TOKEN

    # local SAVE_TOKEN=
    # read -r -p "Save token for future use? [Y/n]: " SAVE_TOKEN
    # Default to yes
    # SAVE_TOKEN=${SAVE_TOKEN:-y}
    # to-lowercase
    # SAVE_TOKEN=$(echo "$SAVE_TOKEN" | awk '{print tolower($0)}')
    # if [ "$SAVE_TOKEN" = "y" ]; then
    #   set_token $PIVNET_API_TOKEN
    # fi
  fi

  local DOWNLOAD_URL=$1
  if [ -z "$DOWNLOAD_URL" ]; then
    read -r -p "Remote file URL: " DOWNLOAD_URL
  fi

  # Test the URL
  local OUTPUT=$(curl -s --data '' -D- -o /dev/null -H "Authorization: Token $PIVNET_API_TOKEN" $DOWNLOAD_URL)
  if echo "$OUTPUT" | grep -q 'Status: 401'; then
    error_and_exit "Invalid token"
  elif echo "$OUTPUT" | grep -q 'Status: 404'; then
    error_and_exit "Invalid Download URL"
  elif echo "$OUTPUT" | grep -q 'Status: 451'; then
    error_and_exit "EULA Not Accepted"
  elif echo "$OUTPUT" | grep -q 'Status: 302'; then
    echo "It Works!"
  fi

  # Get the filename from the redirect and strip the newline char
  # local FILENAME=$(echo "$OUTPUT" | grep -o -E 'filename=.*$' | sed -e 's/filename=//' | sed 's/\r$//')
  local FILENAME=$(echo "$OUTPUT" | grep -o -E 'filename=.*$' | sed -e 's/filename=//' | sed "s/$(printf '\r')//")

  echo "Downloading $FILENAME from $DOWNLOAD_URL"

  curl -o $FILENAME \
    -L --data '' \
    -H "Authorization: Token $PIVNET_API_TOKEN" \
    $DOWNLOAD_URL
}

CMD=$1 ARG=$2

if [ "token" = "$CMD" ]; then
  set_token $ARG
elif [ "download" = "$CMD" ]; then
  download_from_pivnet $ARG
else
  usage_and_exit
fi
