# pcf-stuff

A bunch of stuff I use for Pivotal Cloud Foundry

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

## pivnet

Handy script for downloading stuff from Pivotal Network:
```
$ pivnet download https://network.pivotal.io/api/v2/products/elastic-runtime/releases/2555/product_files/8041/download
```

The script is interactive, so it will ask you for your Pivnet API token as well as prompting to accept the End User License Agreement.

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

The script is interactive, so it will prompt you to login if necessary.
