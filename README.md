# configure-server

```
sudo apt-get update && sudo apt-get upgrade -y
```

## configure swap

```
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
sudo echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

## git

```
sudo apt-get install git -y
```

## unzip

```
sudo apt-get install unzip
```

## nginx

```bash
sudo apt install nginx -y
```

```bash
rm -rf /var/www/html
```

```bash
nano /etc/nginx/nginx.conf

http {
  access_log off;
  error_log off;

  include /var/www/*/nginx/*.conf;
  include /var/www/*/nginx/*/*.conf;
}
```

```bash
nano /etc/nginx/sites-available/default

server {
  listen 80 default_server;
  listen [::]:80 default_server;

  return 404;
}
```

```bash
sudo service nginx restart
```

## nginx basic auth
```bash
sudo apt install apache2-utils
```

create user with creating file
```
sudo htpasswd -c /etc/nginx/.htpasswd username
```

create user without creating file
```
sudo htpasswd /etc/nginx/.htpasswd username
```

add to *.conf
```
auth_basic "Restricted Content";
auth_basic_user_file /etc/nginx/.htpasswd;
```

## certbot

```
sudo apt install certbot python3-certbot-nginx -y

sudo certbot --nginx -d example.com
```

```
sudo crontab -e

0 3 * * * /usr/bin/certbot renew --quiet --post-hook "systemctl reload nginx"
```

## redis

```
sudo apt-get update && sudo apt-get install redis -y
```

```
sudo apt-get install redis-server
sudo systemctl enable redis-server.service
```

## mysql

```
sudo apt update
sudo apt install mysql-server
sudo systemctl start mysql.service

sudo mysql_secure_installation

# change password
sudo mysql
mysql> ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'password';
mysql> exit
```

## php8.3

```
sudo apt-get install software-properties-common
sudo add-apt-repository ppa:ondrej/php
sudo apt install -y php8.3 php8.3-fpm php8.3-redis php8.3-dev php8.3-curl php8.3-gd php8.3-intl php8.3-mysql php8.3-mbstring php8.3-xml php8.3-bcmath php8.3-memcached php8.3-zip php8.3-gmp php-redis
```

```
nano /etc/php/8.3/cli/php.ini

opcache.enable=1
opcache.enable_cli=1
```

```
nano /etc/php/8.3/fpm/php.ini

opcache.enable=1
opcache.enable_cli=1
```

```
nano /etc/php/8.3/mods-available/opcache.ini

zend_extension=opcache.so

opcache.jit=1255
opcache.jit_buffer_size=128M
opcache.jit_debug=0

opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.revalidate_freq=2
opcache.fast_shutdown=1
opcache.enable_file_override=0
```

## composer

```
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === 'dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
php composer-setup.php
php -r "unlink('composer-setup.php');"

sudo mv composer.phar /usr/local/bin/composer
```

## node, npm, yarn, n

```
curl -fsSL https://raw.githubusercontent.com/tj/n/master/bin/n | bash -s lts
npm install -g n
npm install --global yarn
```

## pm2

```
npm install pm2 -g
pm2 startup
```

## aliases

```
nano ~/.bash_aliases

alias .1='cd ../'
alias .2='cd ../../'
alias .3='cd ../../../'
alias .4='cd ../../../../'
alias .5='cd ../../../../../'
alias .6='cd ../../../../../../'
alias .7='cd ../../../../../../../'
alias .8='cd ../../../../../../../../'
alias .9='cd ../../../../../../../../../'
alias .10='cd ../../../../../../../../../../'

alias switch-php='sudo update-alternatives --config php'
```

## ssh

```
ssh-keygen
```
