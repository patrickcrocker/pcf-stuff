 #!/bin/bash

 # AWS: Ubuntu trust 14.04 LTS amd64 hvm:ebs-ssd
 # https://console.aws.amazon.com/ec2/home?region=us-east-1#launchAmi=ami-8e0b9499

set -e

echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections

sudo add-apt-repository ppa:webupd8team/java -y
sudo apt-get update
sudo apt-get -y install oracle-java8-installer
sudo apt-get -y install nginx

#wget http://download.sonatype.com/nexus/3/nexus-3.0.1-01-unix.tar.gz
wget http://download.sonatype.com/nexus/3/nexus-3.0.1-01-unix.sh

echo "b5844cec21c40803f57a41b56feef5fc09da6b2d  nexus-3.0.1-01-unix.sh" > nexus-3.0.1-01-unix.sh.sha1
sha1sum -c nexus-3.0.1-01-unix.sh.sha1

chmod +x nexus-3.0.1-01-unix.sh
./nexus-3.0.1-01-unix.sh

# Setup ssl
sudo mkdir /etc/nginx/ssl
cd /etc/nginx/ssl
sudo openssl genrsa -out root-key.pem 2048
sudo openssl req -x509 -new -nodes -key root-key.pem -days 10000 -out root-ca.pem \
  -subj "/C=US/ST=California/L=Palo Alto/O=Pivotal Software, Inc./OU=Pivotal Demos/CN=Pivotal Demos Root CA/emailAddress=pcrocker@pivotal.io"
sudo openssl genrsa -out server-key.pem 2048
sudo openssl req -new -key server-key.pem -out server-csr.pem \
  -subj "/C=US/ST=California/L=Palo Alto/O=Pivotal Software, Inc./OU=Pivotal Demos/CN=nexus.anvil.pcfdemo.com/emailAddress=pcrocker@pivotal.io"
sudo openssl x509 -req -in server-csr.pem -CA root-ca.pem -CAkey root-key.pem -CAcreateserial -out server-crt.pem -days 10000
cd $OLDPWD
---
sudo mkdir /usr/local/share/ca-certificates/nexus-cert
sudo cp /etc/nginx/ssl/root-ca.pem /usr/local/share/ca-certificates/nexus-cert/root-ca.crt
sudo update-ca-certificates
sudo service docker restart

---
# disable default site
sudo rm /etc/nginx/sites-enabled/default

cat <<'EOF' | sudo tee /etc/nginx/sites-available/nexus.conf
server {
  listen               *:80;
  listen               *:443 ssl;
  server_name          nexus.anvil.pcfdemo.com;
  ssl_certificate      ssl/server-crt.pem;
  ssl_certificate_key  ssl/server-key.pem;

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

  # Rewrite URI to /v2/empty.json
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
    proxy_read_timeout                  900;
  }
}
EOF
sudo service nginx restart
#sudo ln -s /etc/nginx/sites-available/nexus.conf /etc/nginx/sites-enabled/nexus.conf
