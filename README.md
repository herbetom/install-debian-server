# Install Software on Debian Server


Script for the automated install and first configuration of software on an Debian Server.

It will install the following:
- htop
- zip, unzip
- git
- locate

And the following things optional:
- docker
- Webmin
- Apache2, PHP 7.0, certbot (Apache)
- mailcow: dockerized (https://github.com/mailcow/mailcow-dockerized)

## Before you start:
If you plan on Installing Mailcow you should before you start the installation update your DNS according to the following 
minimal DNS configuration. Also you maybe have to wait that the DNS Servers used by LetsEncrypt are updated before you start. 
Otherwise you will probably have problems while the installation because the LetsEncypt client will run into errors.  

https://mailcow.github.io/mailcow-dockerized-docs/prerequisite-dns/#the-minimal-dns-configuration


## How To Use:

Type the following in the console

`bash <(wget -qO- https://raw.githubusercontent.com/herbetom/install-debian-server/master/install.sh)`

During the installation the script will ask you what you want to install (yes or now). 

If you install Mailcow you will get asked what Hostname (FQDN) you want to use. I personaly use usually something like `mail.example.org`.

## Additional Infos
### Mailcow
- Mailcow gets installed into `/opt/mailcow-dockerized/`
- If you want to update Mailcow you should do according to [Mailcow: Automatic update](https://mailcow.github.io/mailcow-dockerized-docs/install-update/#automatic-update) the following:
  - go into the Mailcow directory `cd /opt/mailcow-dockerized/`
  - `./update.sh`
  - if updates where found (you have to read the output) you have to run `./update.sh` 
  - you will have to allow stopping all Mailcow Docker Containes with `y`.
  - now it will update and start Mailcow again after it has finished.
- You may want that the mailcow Mail-Servers (dovecot, postfix, ...) use the SSL certificate of the Host. According to 
[this Issue comment](https://github.com/mailcow/mailcow-dockerized/issues/1421#issuecomment-392275702) the best solution is to 
edit the `docker-compose.override.yml` and add the following 3 lines (you have to use your cert path instead) in 
the `volumes:` section under the line `- ./data/assets/ssl:/etc/ssl/mail/:rw` of `dovecot-mailcow:`, `postfix-mailcow:` and `nginx-mailcow:`. Be carefull, tabs seem not to be allowed(only blanks).
  ```
   - /etc/letsencrypt/live/mail.example.com/fullchain.pem:/etc/ssl/mail/cert.pem:ro
   - /etc/letsencrypt/live/mail.example.com/privkey.pem:/etc/ssl/mail/key.pem:ro
   - /etc/letsencrypt/dhparam.pem:/etc/ssl/mail/dhparams.pem:ro
  ```
  If you have not yet generated a `dhparams.pem` you will probably have to do it now with the command `openssl dhparam -out /etc/letsencrypt/dhparam.pem 4096`. I choose 4096 but thats overkill and it took 5 Minutes to generate. 2048 is also quite secure and should be significant faster. After that you have to restart the mailcow installation with `docker-compose up -d --force-recreate` or something similar.
  It seems to work, but I haven't tested yet how update stable it is. Also you will probably have to restart the containers after the certbot renewed the certificates so that the servers use the new one. Probably there is a more elegant solution which doesn't require manual operations but I haven't found it yet.
