# pcf-stuff

A bunch of stuff for working with Pivotal Cloud Foundry

## pivnet

Handy script for downloading stuff from Pivotal Network:
```
$ pivnet download https://network.pivotal.io/api/v2/products/elastic-runtime/releases/2555/product_files/8041/download
```

Features:
- Prompts user for Pivnet Refresh token
- Prompts user to save the Pivnet Refresh token for future use
- Prompts user to accept End User License Agreement
- Validates checksum of download

## opsman

Handy script for interacting with Pivotal Ops Manager.

### Uploading

First, download a product release from Pivotal Network (see `pivnet` script above).

Then, upload to Ops Manager:
```
$ opsman upload cf-1.8.8-build.1.pivotal
```

You can also upload multiple products:
```
$ opsman upload '*.pivotal'
```

> Please note the use of quoting to prevent pre-mature shell expansion of the wildcard!

You can also upload stemcells:
```
$ opsman upload bosh-stemcell-3363.24-vsphere-esxi-ubuntu-trusty-go_agent.tgz
```

By default, the script targets Ops Manager running on `localhost` but you can override:
```
$ export OPSMAN_HOST=opsman.example.com
```

Features:
- Prompts user for Ops Manager credentials if necessary

### VM types

Returning all VM types
```
$ opsman get-vm-types
```

Deleting all custom VM types
```
$ opsman delete-vm-types
```

Overriding defaults with custom VM types
```
$ opsman set-vm-type --name mytype --cpu 2 --ram 1024 --disk 10240
```

> Please note `set-vm-type` depends on the [jq](https://stedolan.github.io/jq/) cli, which should come with newer versions of Ops Manager.

## boshctl

BOSH Control is used to start or stop all your deployments. This script will
queue the tasks so you can run it and not have to worry about keeping your
terminal session open. **Note: boshctl is supported on versions 2.0 or later of Pivotal Cloud Foundry**

To _login_ to BOSH using Ops Manager credentials (because who can remember the director password, right?)
```
$ boshctl login
```
Once logged in, an alias titled `pcf` will be created in your environment. You can use the `bosh` command line by specifying the `pcf` environment. To see the VMs deployed in your environment:

```
$ bosh -e pcf vms
```

To _stop_ all deployments:
```
$ boshctl stop
```

To _start_ all deployments:
```
$ boshctl start
```

Features:
- Prompts user for Ops Manager credentials if necessary

## install-scripts/azure-om-deploy

This script automates the "Launching an Ops Manager Director Instance on Azure"
instructions found at: http://docs.pivotal.io/pivotalcf/1-8/customizing/azure-om-deploy.html

First, make a copy of the sample config file and then update it with _your_ values:
```
$ cp azure-om-deploy-sample.json azure-om-deploy.json
```

Then, run the script:
```
$ azure-om-deploy azure-om-deploy.json
```
