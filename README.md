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

```
Usage: opsman <command> [options]
Examples:
  opsman login
  opsman unlock
  opsman upload cf-1.8.5-build.4.pivotal
  opsman upload bosh-stemcell-3363.24-vsphere-esxi-ubuntu-trusty-go_agent.tgz
  opsman get-vm-types
  opsman delete-vm-types
  opsman set-vm-type --name mytype --cpu 2 --ram 1024 --disk 10240
```

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
