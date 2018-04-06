#!/bin/sh

read -r -p "Do you really want to start installing Software on the Server? [y/N] " response
  case $response in
    [yY][eE][sS]|[yY])
      echo "OK"
      ;;
    *)
      echo "Script aborted"
      exit 1
    ;;
  esac


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

InstallWebserver=false

read -r -p "Do you want to install Apache2 and PHP7.0? [y/N] " response
  case $response in
    [yY][eE][sS]|[yY])
      echo "Apache2 and PHP7.0 will now be installed"
      InstallWebserver=false

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
      ;;
    *)
    echo "Apache2 and PHP7.0 won't be installed"
    ;;
  esac


read -r -p "Do you want to install Mailcow (a Mail Server with Web Frontend)? [y/N] " response
  case $response in
    [yY][eE][sS]|[yY])
      echo "Mailcow will now be installed"

      #install docker-compose
      echo "Docker Compose is now installed"
      curl -L https://github.com/docker/compose/releases/download/$(curl -Ls https://www.servercow.de/docker-compose/latest.php)/docker-compose-$(uname -s)-$(uname -m) > /usr/local/bin/docker-compose
      chmod +x /usr/local/bin/docker-compose

      #clone mailcow
      cd /opt
      git clone https://github.com/mailcow/mailcow-dockerized
      cd mailcow-dockerized
      ./generate_config.sh

      source /opt/mailcow-dockerized/mailcow.conf

      #if WebServer is installed the MailServer Web Frontend will be Used by a Proxy
      if [[ $InstallWebserver=true ]]; then
        sed -i "s/\(HTTP_PORT *= *\).*/\18080/" /opt/mailcow-dockerized/mailcow.conf
        sed -i "s/\(HTTP_BIND *= *\).*/\1127.0.0.1/" /opt/mailcow-dockerized/mailcow.conf
        sed -i "s/\(HTTPS_PORT *= *\).*/\18443/" /opt/mailcow-dockerized/mailcow.conf
        sed -i "s/\(HTTPS_BIND *= *\).*/\1127.0.0.1/" /opt/mailcow-dockerized/mailcow.conf

        sed -i "s/\(SKIP_LETS_ENCRYPT *= *\).*/\1y/" /opt/mailcow-dockerized/mailcow.conf

        sitesAvailabledomain='/etc/apache2/sites-available/'$MAILCOW_HOSTNAME.conf
        echo "Creating a vhost for $MAILCOW_HOSTNAME"

        ### create virtual host rules file
        echo "
            <VirtualHost *:80>
              ServerName $MAILCOW_HOSTNAME
              DocumentRoot /var/www/html
              RewriteEngine on
              RewriteCond %{SERVER_NAME} =mail.tomhe.de
              RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,NE,R=permanent]
            </VirtualHost>" > $sitesAvailabledomain
        echo "New Virtual Host Created"

        a2ensite $MAILCOW_HOSTNAME
        service apache2 reload

        #certbot --apache

      fi

      #nano mailcow.conf
      docker-compose pull
      #the following command must be run to start Mailcow 'docker-compose up -d'

      ;;
    *)
      echo "Malicow won't be installed"
    ;;
  esac

read -r -p "Do you want to install webmin? [y/N] " response
  case $response in
    [yY][eE][sS]|[yY])
      echo "Webmin will now be installed"
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
      ;;
    *)
      echo "Webmin won't be installed"
    ;;
  esac
