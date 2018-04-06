#!/bin/sh

# upgrade server
apt update
apt upgrade

#install some tools
apt install htop zip unzip locate git -y
updatedb

#install docker
apt install apt-transport-https ca-certificates curl gnupg2 software-properties-common -y
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
apt-key fingerprint 0EBFCD88
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable"
apt update
apt install docker-ce
docker run hello-world

#install docker-compose
curl -L https://github.com/docker/compose/releases/download/$(curl -Ls https://www.servercow.de/docker-compose/latest.php)/docker-compose-$(uname -s)-$(uname -m) > /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

#clone mailcow
cd /opt
git clone https://github.com/mailcow/mailcow-dockerized
cd mailcow-dockerized
./generate_config.sh
sed -i "s/\(HTTP_PORT *= *\).*/\18080/" /opt/mailcow-dockerized/mailcow.conf
sed -i "s/\(HTTP_BIND *= *\).*/\1127.0.0.1/" /opt/mailcow-dockerized/mailcow.conf
sed -i "s/\(HTTPS_PORT *= *\).*/\18443/" /opt/mailcow-dockerized/mailcow.conf
sed -i "s/\(HTTPS_BIND *= *\).*/\1127.0.0.1/" /opt/mailcow-dockerized/mailcow.conf

sed -i "s/\(SKIP_LETS_ENCRYPT *= *\).*/\1y/" /opt/mailcow-dockerized/mailcow.conf

#nano mailcow.conf
docker-compose pull
#the following command must be run to start Mailcow 'docker-compose up -d'

#install webmin
echo 'deb https://download.webmin.com/download/repository sarge contrib' >> /etc/apt/sources.list
curl -fsSL http://www.webmin.com/jcameron-key.asc | sudo apt-key add -
apt update
apt install webmin -y
#only allow localhost for Webmin Access
echo 'allow=127.0.0.1' >> /etc/webmin/miniserv.conf
echo 'trust_real_ip=0' >> /etc/webmin/miniserv.conf

#disable SSL in Webmin
sed -i "s/\(ssl *= *\).*/\10/" /etc/webmin/miniserv.conf
/etc/webmin/restart

#install Apache2 and PHP
apt install apache2 php7.0 -y
systemctl restart apache2
a2enmod rewrite
a2enmod headers
a2enmod http2
a2enmod ssl

#install certbot
apt install python-certbot-apache -t stretch-backports -y

#restart Apache2
systemctl restart apache2
