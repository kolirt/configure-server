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

## node, npm, yarn, n

```
curl -fsSL https://raw.githubusercontent.com/tj/n/master/bin/n | bash -s lts
npm install -g n
npm install --global yarn
```
