#!/bin/bash
#Private Docker Registry
# https://www.digitalocean.com/community/tutorials/how-to-set-up-a-private-docker-registry-on-ubuntu-14-04

# Launch Ubuntu 14.04 AMI on AWS

# Install Docker
wget -qO- https://get.docker.com/ | sh
sudo usermod -aG docker $(whoami)

# Install Docker Compose
sudo apt-get update
sudo apt-get -y install python-pip
sudo pip install docker-compose

# Install htpasswd (which we won't actually need 'cause we are going un-authenticated)
sudo apt-get -y install apache2-utils

# Setup the folders
sudo mkdir -p /opt/docker-registry/data
sudo mkdir /opt/docker-registry/nginx

# Setup ssl
cd /opt/docker-registry/nginx
sudo openssl genrsa -out devdockerCA.key 2048
sudo openssl req -x509 -new -nodes -key devdockerCA.key -days 10000 -out devdockerCA.crt \
  -subj "/C=US/ST=California/L=Palo Alto/O=Pivotal Software, Inc./OU=Pivotal Demos/CN=Pivotal Demos Root CA/emailAddress=pcrocker@pivotal.io"
sudo openssl genrsa -out domain.key 2048
sudo openssl req -new -key domain.key -out dev-docker-registry.com.csr \
  -subj "/C=US/ST=California/L=Palo Alto/O=Pivotal Software, Inc./OU=Pivotal Demos/CN=docker.anvil.pcfdemo.com/emailAddress=pcrocker@pivotal.io"
sudo openssl x509 -req -in dev-docker-registry.com.csr -CA devdockerCA.crt -CAkey devdockerCA.key -CAcreateserial -out domain.crt -days 10000

# Update localhost certs
sudo mkdir /usr/local/share/ca-certificates/docker-dev-cert
sudo cp devdockerCA.crt /usr/local/share/ca-certificates/docker-dev-cert
sudo update-ca-certificates
sudo service docker restart

# Create configs

sudo bash -c "cat >/opt/docker-registry/docker-compose.yml <<EOF
nginx:
  image: \"nginx:1.9\"
  ports:
    - 443:443
  links:
    - registry:registry
  volumes:
    - ./nginx/:/etc/nginx/conf.d
registry:
  image: registry:2
  ports:
    - 127.0.0.1:5000:5000
  environment:
    REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY: /data
  volumes:
    - ./data:/data
EOF"

sudo bash -c "cat >/opt/docker-registry/nginx/registry.conf <<EOF
upstream docker-registry {
  server registry:5000;
}

server {
  listen 443;
  server_name docker.anvil.pcfdemo.com;

  # SSL
  ssl on;
  ssl_certificate /etc/nginx/conf.d/domain.crt;
  ssl_certificate_key /etc/nginx/conf.d/domain.key;

  # disable any limits to avoid HTTP 413 for large image uploads
  client_max_body_size 0;

  # required to avoid HTTP 411: see Issue #1486 (https://github.com/docker/docker/issues/1486)
  chunked_transfer_encoding on;

  location /v2/ {
    # Do not allow connections from docker 1.5 and earlier
    # docker pre-1.6.0 did not properly set the user agent on ping, catch \"Go *\" user agents
    if (\\\$http_user_agent ~ \"^(docker\/1\.(3|4|5(?!\.[0-9]-dev))|Go ).*\\\$\" ) {
      return 404;
    }

    # To add basic authentication to v2 use auth_basic setting plus add_header
    # auth_basic \"registry.localhost\";
    # auth_basic_user_file /etc/nginx/conf.d/registry.password;
    # add_header 'Docker-Distribution-Api-Version' 'registry/2.0' always;

    proxy_pass                          http://docker-registry;
    proxy_set_header  Host              \\\$http_host;   # required for docker client's sake
    proxy_set_header  X-Real-IP         \\\$remote_addr; # pass on real client's IP
    proxy_set_header  X-Forwarded-For   \\\$proxy_add_x_forwarded_for;
    proxy_set_header  X-Forwarded-Proto \\\$scheme;
    proxy_read_timeout                  900;
  }
}
EOF"

sudo bash -c "cat >/etc/init/docker-registry.conf <<EOF
description \"Docker Registry\"

start on runlevel [2345]
stop on runlevel [016]

respawn
respawn limit 10 5

chdir /opt/docker-registry

exec /usr/local/bin/docker-compose up
EOF"

# Start the service
sudo service docker-registry start

# sudo tail -f /var/log/upstart/docker-registry.log
