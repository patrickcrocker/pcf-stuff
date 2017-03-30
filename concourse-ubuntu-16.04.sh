#!/bin/bash
# Concourse install script for ubuntu 16.04
# - Installs Postgres
# - Runs concourse internally on 8080
# - Creates a *valid* 90 day SSL cert via Letsencrypt certbot
# - Includes cron.d job for auto SSL renewal!!
# - Runs HTTPD as a reverse proxy: 80->8080, 443->8080
# - Handles websocket for fly hijack
# - Redirects 80 to 443

# certbot needs this for notifications about your ssl cert
CONCOURSE_DOMAIN_EMAIL=you@example.com
# change this to your domain name
CONCOURSE_DOMAIN=ci.example.com
CONCOURSE_URL=https://$CONCOURSE_DOMAIN
# Optional: change these
CONCOURSE_DB_USER=concourse
CONCOURSE_DB_PASS=concourse
# Required: CHANGE THESE!!!
CONCOURSE_AUTH_USERNAME=admin
CONCOURSE_AUTH_PASSWORD=admin123

# Install packages

sudo add-apt-repository -y ppa:certbot/certbot
sudo apt-get update
sudo apt-get -y install postgresql
sudo apt-get -y install apache2
sudo apt-get -y install python-certbot-apache

# Configure Postgres

sudo -u postgres psql -c "CREATE USER $CONCOURSE_DB_USER WITH PASSWORD '$CONCOURSE_DB_PASS';"
sudo -u postgres createdb -O "$CONCOURSE_DB_USER" atc

# Configure Concourse

sudo mkdir -p /opt/concourse
sudo mkdir -p /tmp/concourse

download_url=$(curl -s https://api.github.com/repos/concourse/concourse/releases | grep browser_download_url | grep concourse_linux_amd64 | head -n 1 | cut -d '"' -f 4)
sudo wget -O /usr/local/bin/concourse $download_url
sudo chmod +x /usr/local/bin/concourse

sudo ssh-keygen -t rsa -f /opt/concourse/host_key -N ''
sudo ssh-keygen -t rsa -f /opt/concourse/worker_key -N ''
sudo ssh-keygen -t rsa -f /opt/concourse/session_signing_key -N ''
sudo cp /opt/concourse/worker_key.pub /opt/concourse/authorized_worker_keys

sudo bash -c 'cat >/etc/systemd/system/concourse-web.service' <<EOF
[Unit]
Description=Concourse CI Web
After=postgresql.service

[Service]
ExecStart=/usr/local/bin/concourse web \\
  --bind-port 8080 \\
  --bind-ip 0.0.0.0 \\
  --basic-auth-username "$CONCOURSE_AUTH_USERNAME" \\
  --basic-auth-password "$CONCOURSE_AUTH_PASSWORD" \\
  --session-signing-key /opt/concourse/session_signing_key \\
  --tsa-host-key /opt/concourse/host_key \\
  --tsa-authorized-keys /opt/concourse/authorized_worker_keys \\
  --postgres-data-source "postgres://$CONCOURSE_DB_USER:$CONCOURSE_DB_PASS@127.0.0.1:5432/atc?sslmode=disable" \\
  --external-url "http://$CONCOURSE_URL"

User=root
Group=root

Type=simple

[Install]
WantedBy=default.target
EOF

sudo bash -c 'cat >/etc/systemd/system/concourse-worker.service' <<EOF
[Unit]
Description=Concourse CI Worker
After=concourse-web.service

[Service]
ExecStart=/usr/local/bin/concourse worker \\
  --work-dir /tmp/concourse \\
  --tsa-host 127.0.0.1 \\
  --tsa-public-key /opt/concourse/host_key.pub \\
  --tsa-worker-private-key /opt/concourse/worker_key

User=root
Group=root

Type=simple

[Install]
WantedBy=default.target
EOF

sudo systemctl enable concourse-web.service
sudo systemctl start concourse-web.service

sudo systemctl enable concourse-worker.service
sudo systemctl start concourse-worker.service

# Configure SSL CERT

sudo certbot -n --apache --agree-tos \
  --domains $CONCOURSE_DOMAIN \
  --email $CONCOURSE_DOMAIN_EMAIL

# Configure HTTPD

sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod proxy_wstunnel
sudo a2enmod rewrite

sudo bash -c 'cat >/etc/apache2/sites-available/000-concourse.conf' <<EOF
<VirtualHost *:80>
    ServerName $CONCOURSE_DOMAIN
    Redirect "/" "https://$CONCOURSE_DOMAIN/"
</VirtualHost>
<IfModule mod_ssl.c>
  <VirtualHost *:443>

    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined

    SSLCertificateFile /etc/letsencrypt/live/$CONCOURSE_DOMAIN/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/$CONCOURSE_DOMAIN/privkey.pem
    Include /etc/letsencrypt/options-ssl-apache.conf
    ServerName $CONCOURSE_DOMAIN

    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} =websocket [NC]
    RewriteRule /(.*)           ws://localhost:8080/\$1 [P,L]
    RewriteCond %{HTTP:Upgrade} !=websocket [NC]
    RewriteRule /(.*)           http://localhost:8080/\$1 [P,L]

    ProxyPassReverse / http://localhost:8080/

  </VirtualHost>
</IfModule>
EOF
cat /etc/apache2/sites-available/000-concourse.conf

sudo a2ensite 000-concourse
sudo systemctl reload apache2
