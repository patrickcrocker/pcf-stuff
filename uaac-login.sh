#!/bin/bash

if [ -z "$OPSMAN_USER" ]; then
  echo "Ops Manager User: "
  read -r OPSMAN_USER
fi

if [ -z "$OPSMAN_PASS" ]; then
  echo "Ops Manager Pass: "
  read -r OPSMAN_PASS
fi

uaac target https://localhost/uaa --ca-cert /var/tempest/workspaces/default/root_ca_certificate

uaac token owner get opsman $OPSMAN_USER -p $OPSMAN_PASS -s ''

export UAA_ACCESS_TOKEN=$(uaac context $OPSMAN_USER | grep access_token | awk '{ print $2 }')
