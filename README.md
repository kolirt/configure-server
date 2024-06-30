# configure-server

```
sudo apt-get update
sudo apt-get upgrade
```

## git

```
sudo apt-get install git
```

## nginx

```
sudo apt install nginx
```

```
rm -rf /var/www/html
```

```
nano /etc/nginx/nginx.conf

http {
  access_log off;
  error_log off;

  include /var/www/*/nginx/*.conf;
  include /var/www/*/nginx/*/*.conf;
}
```

```
nano /etc/nginx/sites-available/default

server {
  listen 80 default;
  listen [::]:80 default;

  return 404;
}
```

```
sudo service nginx restart
```

## redis

```
sudo apt-get install redis-server
sudo systemctl enable redis-server.service
```

## php8.3

```
sudo apt-get install software-properties-common
sudo add-apt-repository ppa:ondrej/php
sudo apt install -y php8.3 php8.3-fpm php8.3-dev php8.3-curl php8.3-gd php8.3-intl php8.3-mysql php8.3-mbstring php8.3-xml php8.3-bcmath php8.3-memcached php8.3-zip php8.3-gmp php-redis
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

opcache.jit=1255
opcache.jit_buffer_size=128M
opcache.jit_debug=0
opcache.jit_hot_func=1
opcache.jit_hot_func_threshold=5
```

## composer

```
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === 'dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
php composer-setup.php
php -r "unlink('composer-setup.php');"
```

## node, npm, yarn, n

```
curl -fsSL https://raw.githubusercontent.com/tj/n/master/bin/n | bash -s lts
npm install -g n
npm install --global yarn
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
