check_nginx() { require_cmd nginx && systemctl is-active --quiet nginx 2>/dev/null; }

module_nginx() {
  pkg_install nginx
  rm -rf /var/www/html

  cat > /etc/nginx/nginx.conf <<'NGX'
user www-data;
worker_processes auto;
worker_rlimit_nofile 65535;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
  worker_connections 4096;
  multi_accept on;
  use epoll;
}

http {
  sendfile on;
  tcp_nopush on;
  tcp_nodelay on;
  types_hash_max_size 2048;
  server_tokens off;

  keepalive_timeout 65;
  keepalive_requests 1000;

  client_max_body_size 32m;
  client_body_timeout 30s;
  client_header_timeout 30s;
  send_timeout 30s;

  include /etc/nginx/mime.types;
  default_type application/octet-stream;

  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_prefer_server_ciphers on;
  ssl_session_cache shared:SSL:10m;
  ssl_session_timeout 10m;

  # Access log off by default (per-site can re-enable); error_log stays on at warn.
  access_log off;
  error_log /var/log/nginx/error.log warn;

  gzip on;
  gzip_vary on;
  gzip_min_length 1024;
  gzip_comp_level 5;
  gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript image/svg+xml;

  include /etc/nginx/conf.d/*.conf;
  include /etc/nginx/sites-enabled/*;
  include /var/www/*/nginx/*.conf;
  include /var/www/*/nginx/*/*.conf;
}
NGX

  cat > /etc/nginx/sites-available/default <<'SITE'
server {
  listen 80 default_server;
  listen [::]:80 default_server;

  return 404;
}
SITE

  nginx -t
  systemctl restart nginx
  systemctl enable nginx
}
