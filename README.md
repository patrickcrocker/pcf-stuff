# pcf-stuff

A bunch of stuff I use for Pivotal Cloud Foundry

## pivnet

Handy script for downloading stuff from Pivotal Network:

First, set your pivnet api token:
```
$ pivnet token sampleAsdf80ga67
```

Using your browser, login to Pivotal Network, accept the product EULA, get the download link, then do this:
```
$ pivnet download https://network.pivotal.io/api/v2/products/elastic-runtime/releases/2555/product_files/8041/download
```

## opsman

Handy script for uploading stuff to Pivotal Ops Manager:

First, download something from Pivotal Network (see pivnet script above).

Second, login to uaac:
```
$ opsman login
```

Then, upload your download to Ops Manager:
```
$ opsman upload cf-1.8.8-build.1.pivotal
```
