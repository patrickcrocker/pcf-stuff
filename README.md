# pcf-stuff

A bunch of stuff I use for Pivotal Cloud Foundry

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

The script is interactive, so it will prompt you to login if necessary.
