 #!/bin/bash

# Nexus Repository Manager configured for Private Docker Registry

# AWS: Ubuntu trust 14.04 LTS amd64 hvm:ebs-ssd
# https://console.aws.amazon.com/ec2/home?region=us-east-1#launchAmi=ami-8e0b9499

# Add Java PPA
echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections
sudo add-apt-repository ppa:webupd8team/java -y

# Install packages
sudo apt-get update
sudo apt-get -y install oracle-java8-installer
sudo apt-get -y install nginx

# Install Docker (for local pull/push to Nexus)
wget -qO- https://get.docker.com/ | sh
sudo usermod -aG docker $(whoami)
# logout and logback in

#wget http://download.sonatype.com/nexus/3/nexus-3.0.1-01-unix.tar.gz
wget http://download.sonatype.com/nexus/3/nexus-3.0.1-01-unix.sh
echo "b5844cec21c40803f57a41b56feef5fc09da6b2d  nexus-3.0.1-01-unix.sh" > nexus-3.0.1-01-unix.sh.sha1
sha1sum -c nexus-3.0.1-01-unix.sh.sha1
chmod +x nexus-3.0.1-01-unix.sh
# Install script is interactive, just accept all the default values
./nexus-3.0.1-01-unix.sh

# Setup ssl
sudo mkdir /etc/nginx/ssl
cd /etc/nginx/ssl
sudo openssl genrsa -out root-ca.key 2048
sudo openssl req -x509 -new -nodes -key root-ca.key -days 10000 -out root-ca.crt \
  -subj "/C=US/ST=California/L=Palo Alto/O=Pivotal Software, Inc./OU=Pivotal Demos/CN=Pivotal Demos Root CA/emailAddress=pcrocker@pivotal.io"
sudo openssl genrsa -out server.key 2048
sudo openssl req -new -key server.key -out server.csr \
  -subj "/C=US/ST=California/L=Palo Alto/O=Pivotal Software, Inc./OU=Pivotal Demos/CN=nexus.anvil.pcfdemo.com/emailAddress=pcrocker@pivotal.io"
sudo openssl x509 -req -in server.csr -CA root-ca.crt -CAkey root-ca.key -CAcreateserial -out server.crt -days 10000
cd $OLDPWD

# Update localhost certs
sudo mkdir /usr/local/share/ca-certificates/nexus-cert
sudo cp /etc/nginx/ssl/root-ca.crt /usr/local/share/ca-certificates/nexus-cert/root-ca.crt
sudo update-ca-certificates
sudo service docker restart

# Create empty json file
mkdir -p /home/ubuntu/www/v2
echo "{}" > /home/ubuntu/www/v2/empty.json

---
# disable default site
sudo rm /etc/nginx/sites-enabled/default

cat <<'EOF' | sudo tee /etc/nginx/sites-available/nexus.conf
server {
  listen               *:443 ssl;
  server_name          nexus.anvil.pcfdemo.com;
  ssl_certificate      ssl/server.crt;
  ssl_certificate_key  ssl/server.key;

  # disable any limits to avoid HTTP 413 for large image uploads
  client_max_body_size 0;

  # required to avoid HTTP 411: see Issue #1486 (https://github.com/docker/docker/issues/1486)
  chunked_transfer_encoding on;

  # Nexus web app
  location / {
    proxy_pass                          http://localhost:8081;
    proxy_set_header  Host              $http_host;   # required for docker client's sake
    proxy_set_header  X-Real-IP         $remote_addr; # pass on real client's IP
    proxy_set_header  X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header  X-Forwarded-Proto $scheme;
    proxy_read_timeout                  900;
  }

  # Empty JSON file to satisfy Cloud Foundry's need to have GET /v2/ return an empty json string
  root /home/ubuntu/www;

  # This does two things:
  # 1. Disables Nexus authentication on /v2/
  # 2. Rewrite URI to /v2/empty.json
  location = /v2/ {
    index empty.json;
  }

  # Match the re-written URI to serve our static empty.json file
  location = /v2/empty.json {
  }

  # Everything else gets proxied to Nexus
  location /v2/ {
    proxy_pass                          http://localhost:5000;
    proxy_set_header  Host              $http_host;   # required for docker client's sake
    proxy_set_header  X-Real-IP         $remote_addr; # pass on real client's IP
    proxy_set_header  X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header  X-Forwarded-Proto $scheme;
    # This is the default Nexus admin credentials, change as appropriate!
    proxy_set_header  Authorization     "Basic YWRtaW46YWRtaW4xMjM=";
    proxy_read_timeout                  900;
  }
}
EOF

sudo ln -s /etc/nginx/sites-available/nexus.conf /etc/nginx/sites-enabled/nexus.conf

sudo service nginx restart

# Configure Nexus for private Docker Registry:
# NexusUI -> Settings -> Repositories -> Create repository:
#   Recipe: docker (hosted)
#   Name: docker-hosted
#   HTTP: 5000
#   Blob store: default
pause
