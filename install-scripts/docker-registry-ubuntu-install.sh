#!/bin/bash

# Private Docker Registry script base on:
# https://www.digitalocean.com/community/tutorials/how-to-set-up-a-private-docker-registry-on-ubuntu-14-04

# AWS: Ubuntu trust 14.04 LTS amd64 hvm:ebs-ssd
# https://console.aws.amazon.com/ec2/home?region=us-east-1#launchAmi=ami-8e0b9499

# Install Docker
wget -qO- https://get.docker.com/ | sh
sudo usermod -aG docker $(whoami)

# Install Docker Compose
sudo apt-get update
sudo apt-get -y install python-pip
sudo pip install docker-compose

# Install htpasswd (which we won't actually need 'cause we are going un-authenticated)
#sudo apt-get -y install apache2-utils

# Setup the folders
sudo mkdir -p /opt/docker-registry/data
sudo mkdir /opt/docker-registry/nginx

# Setup ssl
cd /opt/docker-registry/nginx
sudo openssl genrsa -out root-ca.key 2048
sudo openssl req -x509 -new -nodes -key root-ca.key -days 10000 -out root-ca.crt \
  -subj "/C=US/ST=California/L=Palo Alto/O=Pivotal Software, Inc./OU=Pivotal Demos/CN=Pivotal Demos Root CA/emailAddress=pcrocker@pivotal.io"
sudo openssl genrsa -out server.key 2048
sudo openssl req -new -key server.key -out server.csr \
  -subj "/C=US/ST=California/L=Palo Alto/O=Pivotal Software, Inc./OU=Pivotal Demos/CN=docker.anvil.pcfdemo.com/emailAddress=pcrocker@pivotal.io"
sudo openssl x509 -req -in server.csr -CA root-ca.crt -CAkey root-ca.key -CAcreateserial -out server.crt -days 10000

# Update localhost certs
sudo mkdir /usr/local/share/ca-certificates/docker-registry
sudo cp root-ca.crt /usr/local/share/ca-certificates/docker-registry
sudo update-ca-certificates
sudo service docker restart
# you may need to logout and then log back in before running `docker push`

# Create configs

cat <<'EOF' | sudo tee /opt/docker-registry/docker-compose.yml
nginx:
  image: "nginx:1.9"
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
EOF

cat <<'EOF' | sudo tee /opt/docker-registry/nginx/registry.conf
upstream docker-registry {
  server registry:5000;
}

server {
  listen 443;
  server_name docker.anvil.pcfdemo.com;

  # SSL
  ssl on;
  ssl_certificate /etc/nginx/conf.d/server.crt;
  ssl_certificate_key /etc/nginx/conf.d/server.key;

  # disable any limits to avoid HTTP 413 for large image uploads
  client_max_body_size 0;

  # required to avoid HTTP 411: see Issue #1486 (https://github.com/docker/docker/issues/1486)
  chunked_transfer_encoding on;

  location /v2/ {
    # Do not allow connections from docker 1.5 and earlier
    # docker pre-1.6.0 did not properly set the user agent on ping, catch "Go *" user agents
    if ($http_user_agent ~ "^(docker\/1\.(3|4|5(?!\.[0-9]-dev))|Go ).*$" ) {
      return 404;
    }

    # To add basic authentication to v2 use auth_basic setting plus add_header
    # auth_basic "registry.localhost";
    # auth_basic_user_file /etc/nginx/conf.d/registry.password;
    # add_header 'Docker-Distribution-Api-Version' 'registry/2.0' always;

    proxy_pass                          http://docker-registry;
    proxy_set_header  Host              $http_host;   # required for docker client's sake
    proxy_set_header  X-Real-IP         $remote_addr; # pass on real client's IP
    proxy_set_header  X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header  X-Forwarded-Proto $scheme;
    proxy_read_timeout                  900;
  }
}
EOF

cat <<'EOF' | sudo tee /etc/init/docker-registry.conf
description "Docker Registry"

start on runlevel [2345]
stop on runlevel [016]

respawn
respawn limit 10 5

chdir /opt/docker-registry

exec /usr/local/bin/docker-compose up
EOF

# Start the service
sudo service docker-registry start
