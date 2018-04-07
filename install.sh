#!/bin/sh

beep(){
  echo -en "\007"
}

installDocker(){
  echo "Docker will now be installed"
  apt install apt-transport-https ca-certificates curl gnupg2 software-properties-common -y
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
  apt-key fingerprint 0EBFCD88
  sudo add-apt-repository \
     "deb [arch=amd64] https://download.docker.com/linux/debian \
     $(lsb_release -cs) \
     stable"
  apt update
  apt install docker-ce -y
  docker run hello-world
}

beep
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
apt upgrade -y

#install some tools
apt install htop zip unzip locate git -y
updatedb

DockerInstalled=false
#install docker if neccesary
docker -v &> /dev/null
if [ ! $? -eq 0 ]; then
  read -r -p "Do you want to install Docker? [y/N] " response
    case $response in
      [yY][eE][sS]|[yY])
        installDocker
        DockerInstalled=true
        ;;
      *)
      echo ""
      ;;
    esac
  else
    DockerInstalled=true
    echo "Docker is already installed on the system. No need to install"
fi

WebserverInstalled=false
beep
read -r -p "Do you want to install Apache2 and PHP7.0 as well as certbot? [y/N] " response
  case $response in
    [yY][eE][sS]|[yY])
      echo "Apache2 and PHP7.0 will now be installed"

      #install Apache2 and PHP
      apt install apache2 php7.0 -y
      systemctl restart apache2
      a2enmod rewrite
      a2enmod headers
      a2enmod http2
      a2enmod ssl
      a2enmod proxy
      a2enmod proxy_http
      a2enmod proxy_http2

      #install certbot
      apt install python-certbot-apache -t stretch-backports -y

      #restart Apache2
      systemctl restart apache2

      WebserverInstalled=true
      ;;
    *)
    echo ""
    ;;
  esac

MailcowInstalled=false
if [ ! -d "/opt/mailcow-dockerized/" ]; then
  beep
  read -r -p "Do you want to install Mailcow (a Mail Server with Web Frontend)? [y/N] " response
    case $response in
      [yY][eE][sS]|[yY])
        echo "Mailcow will now be installed"

        # install Docker if not installed
        if [ ! $DockerInstalled == "true" ]; then
          installDocker
        fi

        #install docker-compose if not already installed
        if [ ! -d "/usr/local/bin/docker-compose" ]; then
          echo "Docker Compose is now installed"
          curl -L https://github.com/docker/compose/releases/download/$(curl -Ls https://www.servercow.de/docker-compose/latest.php)/docker-compose-$(uname -s)-$(uname -m) > /usr/local/bin/docker-compose
          chmod +x /usr/local/bin/docker-compose
        fi

        #clone mailcow
        cd /opt
        git clone https://github.com/mailcow/mailcow-dockerized
        cd mailcow-dockerized
        beep
        ./generate_config.sh

        source /opt/mailcow-dockerized/mailcow.conf

        #if WebServer is installed the MailServer Web Frontend will be Used by a Proxy
        if [ $WebserverInstalled == true ]; then
          sed -i "s/\(HTTP_PORT *= *\).*/\18080/" /opt/mailcow-dockerized/mailcow.conf
          sed -i "s/\(HTTP_BIND *= *\).*/\1127.0.0.1/" /opt/mailcow-dockerized/mailcow.conf
          sed -i "s/\(HTTPS_PORT *= *\).*/\18443/" /opt/mailcow-dockerized/mailcow.conf
          sed -i "s/\(HTTPS_BIND *= *\).*/\1127.0.0.1/" /opt/mailcow-dockerized/mailcow.conf

          sed -i "s/\(SKIP_LETS_ENCRYPT *= *\).*/\1y/" /opt/mailcow-dockerized/mailcow.conf

          sitesAvailabledomain='/etc/apache2/sites-available/'$MAILCOW_HOSTNAME.conf
          echo "Creating a vhost for $MAILCOW_HOSTNAME"

          ### create virtual host rules file

          maindomain=$(expr match "$MAILCOW_HOSTNAME" '.*\.\(.*\..*\)')
          echo "<VirtualHost *:80>" > $sitesAvailabledomain
          echo "  ServerName $MAILCOW_HOSTNAME" >> $sitesAvailabledomain
          echo "  ServerAlias autodiscover.$maindomain" >> $sitesAvailabledomain
          echo "  ServerAlias autoconfig.$maindomain" >> $sitesAvailabledomain
          echo "  DocumentRoot \"/var/www/html\"" >> $sitesAvailabledomain
          #echo "  <IfModule mod_ssl.c>" >> $sitesAvailabledomain
          echo "  <Directory \"/var/www/html\">" >> $sitesAvailabledomain
          echo "    allow from all" >> $sitesAvailabledomain
          echo "    Options None" >> $sitesAvailabledomain
          echo "    Require all granted" >> $sitesAvailabledomain
          echo "  </Directory>" >> $sitesAvailabledomain
          echo "  Protocols h2 http/1.1" >> $sitesAvailabledomain
          echo "  ProxyPass / http://127.0.0.1:8080/" >> $sitesAvailabledomain
          echo "  ProxyPassReverse / http://127.0.0.1:8080/" >> $sitesAvailabledomain
          echo "  ProxyPreserveHost On" >> $sitesAvailabledomain
          echo "  ProxyAddHeaders On" >> $sitesAvailabledomain
          echo "  <If \"%{HTTPS} == 'on'\" >" >> $sitesAvailabledomain
          echo "    RequestHeader set X-Forwarded-Proto \"https\"" >> $sitesAvailabledomain
          echo "  </If>" >> $sitesAvailabledomain
          #echo "  </IfModule>" >> $sitesAvailabledomain
          echo "</VirtualHost>" >> $sitesAvailabledomain

          echo "New Virtual Host Created"

          a2ensite $MAILCOW_HOSTNAME
          service apache2 reload

          #obtain ssl certificate
          beep
          certbot --apache --agree-tos --no-eff-email --redirect -d $MAILCOW_HOSTNAME -d autodiscover.$maindomain -d autoconfig.$maindomain

        fi

        beep
        read -r -p "Do you want to make changes to the mailcow.conf? [y/N] " response
          case $response in
            [yY][eE][sS]|[yY])
              nano /opt/mailcow-dockerized/mailcow.conf
              ;;
            *)
            ;;
          esac

        docker-compose pull
        #the following command must be run to start Mailcow 'docker-compose up -d'
        MailcowInstalled=true
        ;;
      *)
      echo ""
      ;;
    esac
fi

if [ ! -d "/etc/webmin/" ]; then
  beep
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
      echo ""
      ;;
    esac
fi

if [ $MailcowInstalled == true ]; then
  echo ""
  beep
  read -r -p "Do you want to start mailcow now? The default credentials are admin/moohoo. [y/N] " response
    case $response in
      [yY][eE][sS]|[yY])
        cd /opt/mailcow-dockerized
        docker-compose up -d
        echo "Mailcow is now started!"
        ;;
      *)
      echo ""
      echo "***************************************************"
      echo "* To start Mailcow 'docker-compose up -d' must be *"
      echo "* run within the folder /opt/mailcow-dockerized/  *"
      echo "* This will allow you to acces it.                *"
      echo "***************************************************"
      ;;
    esac

fi

echo "#############################################################"
echo ""
echo "Scipt finished! Thanks for using! I hope everything works!"
if [ $MailcowInstalled == true ]; then
  echo "The default credentials for mailcow are admin/moohoo."
