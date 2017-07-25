# pcf-stuff

A bunch of stuff for working with Pivotal Cloud Foundry

## pivnet

Handy script for downloading stuff from Pivotal Network:
```
$ pivnet download https://network.pivotal.io/api/v2/products/elastic-runtime/releases/2555/product_files/8041/download
```

Features:
- Prompts user for Pivnet API token
- Prompts user to save the Pivnet API token for future use
- Prompts user to accept End User License Agreement
- Validates MD5 checksum of download

## opsman

Handy script for uploading stuff to Pivotal Ops Manager:

First, download something from Pivotal Network (see pivnet script above).

Then, upload your download to Ops Manager:
```
$ opsman upload cf-1.8.8-build.1.pivotal
```

You can also upload multiple stuff:
```
$ opsman upload '*.pivotal'
```

> Please note the use of quoting to prevent pre-mature shell expansion of the wildcard!

Features:
- Prompts user for Ops Manager credentials if necessary

## boshctl

BOSH Control is used to start or stop all your deployments. This script will
queue the tasks so you can run it and not have to worry about keeping your
terminal session open.

To _login_ to BOSH using Ops Manager credentials (because who can remember the director password, right?)
```
$ boshctl login
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

## azure-om-deploy

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
