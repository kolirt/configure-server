#!/usr/bin/env bash

set -euo pipefail

readonly C_RESET=$'\033[0m'
readonly C_INFO=$'\033[1;34m'
readonly C_WARN=$'\033[1;33m'
readonly C_ERR=$'\033[1;31m'
readonly C_OK=$'\033[1;32m'

declare -a CREDENTIALS_LOG=()
declare -a INSTALLED=()
declare -a FAILED=()
declare -a SKIPPED=()

log_info()  { printf '%s[INFO]%s %s\n'  "$C_INFO" "$C_RESET" "$*"; }
log_warn()  { printf '%s[WARN]%s %s\n'  "$C_WARN" "$C_RESET" "$*" >&2; }
log_error() { printf '%s[ERR ]%s %s\n'  "$C_ERR"  "$C_RESET" "$*" >&2; }
log_ok()    { printf '%s[ OK ]%s %s\n'  "$C_OK"   "$C_RESET" "$*"; }

log_cred() { CREDENTIALS_LOG+=("$1: $2"); }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)."
    exit 1
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1
}

pkg_install() {
  DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

# Dispatch to per-module check function: returns 0 if the module looks already
# configured on this host, 1 otherwise. Modules without a check are never
# considered done (always re-runnable).
is_module_done() {
  local id="$1" fn="check_${1//-/_}"
  if declare -F "$fn" >/dev/null; then
    "$fn"
  else
    return 1
  fi
}

ensure_fzf() {
  if ! require_cmd fzf; then
    log_info "Installing fzf..."
    pkg_install fzf
  fi
}

prompt_secret() {
  local label="$1" out_var="$2" p1 p2
  while true; do
    read -rsp "$label: " p1; echo
    read -rsp "$label (confirm): " p2; echo
    if [[ "$p1" == "$p2" && -n "$p1" ]]; then
      printf -v "$out_var" '%s' "$p1"
      return 0
    fi
    log_warn "Values do not match or are empty. Try again."
  done
}

prompt_line() {
  local label="$1" out_var="$2" val
  read -rp "$label: " val
  printf -v "$out_var" '%s' "$val"
}

# Order here is the execution order, and the order shown in the whiptail menu.
readonly MODULES=(
  "system-update|System update (apt update && upgrade)"
  "swap|Swap file (auto-sized)"
  "git|git"
  "unzip|unzip"
  "nginx|nginx + default config"
  "nginx-basic-auth|nginx basic auth (htpasswd)"
  "certbot|Let's Encrypt (certbot)"
  "redis|Redis"
  "mysql|MySQL server"
  "php|PHP (version picked interactively)"
  "composer|Composer"
  "node|Node.js + n + yarn"
  "pm2|pm2"
  "aliases|bash aliases"
  "ssh-keygen|ssh-keygen"
)

select_modules() {
  local -a lines=()
  local entry id desc status
  for entry in "${MODULES[@]}"; do
    id="${entry%%|*}"
    desc="${entry#*|}"
    if is_module_done "$id"; then
      status="[x]"
    else
      status="[ ]"
    fi
    lines+=("$(printf '%s\t%-20s  %s' "$status" "$id" "$desc")")
  done

  local selection
  selection=$(printf '%s\n' "${lines[@]}" | fzf \
    --multi \
    --height=80% \
    --layout=reverse \
    --border \
    --delimiter='\t' \
    --prompt="modules> " \
    --header="Tab: toggle   Enter: confirm   Ctrl-A: select all   Ctrl-D: deselect all   [x] = already configured" \
    --bind="ctrl-a:select-all,ctrl-d:deselect-all") || {
    log_warn "Selection cancelled."
    exit 0
  }

  # Line format is "<status>\t<id>  <description>"; extract id field.
  awk -F'\t' '{print $2}' <<<"$selection" | awk '{print $1}'
}

run_module() {
  local id="$1" fn="module_${1//-/_}"
  if ! declare -F "$fn" >/dev/null; then
    log_error "No implementation for module '$id' (function $fn missing)."
    FAILED+=("$id")
    return 0
  fi
  if is_module_done "$id"; then
    log_info "=== Skipping: $id (already configured) ==="
    SKIPPED+=("$id")
    return 0
  fi
  log_info "=== Running: $id ==="
  if "$fn"; then
    INSTALLED+=("$id")
    log_ok "=== Done: $id ==="
  else
    log_warn "=== Failed: $id (continuing) ==="
    FAILED+=("$id")
  fi
}

print_summary() {
  echo
  echo "============================================================="
  echo " configure-server setup complete"
  echo "-------------------------------------------------------------"
  if ((${#INSTALLED[@]})); then
    echo " Installed: ${INSTALLED[*]}"
  fi
  if ((${#SKIPPED[@]})); then
    echo " Skipped:   ${SKIPPED[*]} (already completed previously)"
  fi
  if ((${#FAILED[@]})); then
    echo " Failed:    ${FAILED[*]}"
  fi
  echo "-------------------------------------------------------------"
  if ((${#CREDENTIALS_LOG[@]})); then
    echo " Credentials (save these — not persisted anywhere):"
    local line
    for line in "${CREDENTIALS_LOG[@]}"; do
      echo "   $line"
    done
  else
    echo " No credentials were captured."
  fi
  echo "============================================================="
}

module_system_update() {
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
}

check_swap()              { [[ -n "$(swapon --show --noheadings 2>/dev/null || true)" ]]; }
check_git()               { require_cmd git; }
check_unzip()             { require_cmd unzip; }
check_nginx()             { require_cmd nginx && systemctl is-active --quiet nginx 2>/dev/null; }
check_nginx_basic_auth()  { [[ -f /etc/nginx/.htpasswd ]] && require_cmd htpasswd; }
check_certbot()           { require_cmd certbot && crontab -l 2>/dev/null | grep -qF 'certbot renew'; }
check_redis()             { require_cmd redis-server && systemctl is-active --quiet redis-server 2>/dev/null; }
check_mysql()             { require_cmd mysql && systemctl is-active --quiet mysql 2>/dev/null; }
check_php()               { require_cmd php && php -v 2>/dev/null | grep -qE '^PHP [0-9]+\.[0-9]+'; }
check_composer()          { require_cmd composer; }
check_node()              { require_cmd node && require_cmd yarn && require_cmd n; }
check_pm2()               { require_cmd pm2 && systemctl list-unit-files 2>/dev/null | grep -qE '^pm2-[^ ]+\.service'; }
check_aliases() {
  local owner home_dir
  if [[ -n "${SUDO_USER:-}" ]] && id -u "$SUDO_USER" >/dev/null 2>&1; then
    owner="$SUDO_USER"
  else
    owner="root"
  fi
  home_dir=$(getent passwd "$owner" | cut -d: -f6)
  [[ -n "$home_dir" && -f "$home_dir/.bash_aliases" ]] && \
    grep -qF '# configure-server aliases' "$home_dir/.bash_aliases"
}
check_ssh_keygen() {
  local owner home_dir
  owner="${SUDO_USER:-root}"
  home_dir=$(getent passwd "$owner" | cut -d: -f6)
  [[ -n "$home_dir" ]] && \
    compgen -G "$home_dir/.ssh/id_*" >/dev/null
}

compute_swap_gb() {
  local kb gb
  kb=$(awk '/MemTotal/{print $2}' /proc/meminfo)
  gb=$(( (kb + 1048575) / 1048576 ))
  if   (( gb <= 2 ));  then echo $(( gb * 2 ))
  elif (( gb <= 8 ));  then echo "$gb"
  elif (( gb <= 64 )); then
    local half=$(( gb / 2 ))
    (( half < 4 )) && half=4
    echo "$half"
  else
    echo 4
  fi
}

module_swap() {
  if [[ -n "$(swapon --show --noheadings 2>/dev/null || true)" ]]; then
    log_info "Swap already active — skipping."
    return 0
  fi
  local size_gb
  size_gb=$(compute_swap_gb)
  log_info "Creating ${size_gb}G swap at /swapfile..."
  fallocate -l "${size_gb}G" /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  if ! grep -qE '^\s*/swapfile\s' /etc/fstab; then
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
  fi
}

module_git() {
  if require_cmd git; then
    log_info "git already present — skipping install."
    return 0
  fi
  pkg_install git
}

module_unzip() {
  if require_cmd unzip; then
    log_info "unzip already present — skipping install."
    return 0
  fi
  pkg_install unzip
}

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

module_nginx_basic_auth() {
  pkg_install apache2-utils
  local user pass flag="-c"
  prompt_line "Basic-auth username" user
  if [[ -z "$user" ]]; then
    log_warn "Empty username — aborting basic-auth setup."
    return 1
  fi
  prompt_secret "Basic-auth password for '$user'" pass

  [[ -f /etc/nginx/.htpasswd ]] && flag=""
  # shellcheck disable=SC2086
  htpasswd -b $flag /etc/nginx/.htpasswd "$user" "$pass"

  log_cred "nginx basic-auth (user $user)" "$pass"
  log_info "Add to any site config to enable:"
  cat <<'HINT'
    auth_basic "Restricted Content";
    auth_basic_user_file /etc/nginx/.htpasswd;
HINT
}

module_certbot() {
  pkg_install certbot python3-certbot-nginx
  local domain email
  prompt_line "Domain for certbot (e.g. example.com)" domain
  if [[ -z "$domain" ]]; then
    log_warn "Empty domain — skipping certificate issuance."
    return 1
  fi
  prompt_line "Email for Let's Encrypt notifications" email
  if [[ -z "$email" ]]; then
    log_warn "Empty email — skipping certificate issuance."
    return 1
  fi

  certbot --nginx --non-interactive --agree-tos -m "$email" -d "$domain"

  local cron_line='0 3 * * * /usr/bin/certbot renew --quiet --post-hook "systemctl reload nginx"'
  local current
  current=$(crontab -l 2>/dev/null || true)
  if ! grep -qF 'certbot renew' <<<"$current"; then
    { echo "$current"; echo "$cron_line"; } | sed '/^$/d' | crontab -
    log_info "Added certbot renew cron entry."
  else
    log_info "certbot renew cron already present."
  fi

  log_cred "certbot" "$domain ($email)"
}

module_redis() {
  pkg_install redis-server
  systemctl enable redis-server.service
  systemctl restart redis-server.service
}

module_mysql() {
  pkg_install mysql-server
  systemctl enable mysql
  systemctl start mysql

  local root_pw
  prompt_secret "New MySQL root password" root_pw

  local auth_plugin
  auth_plugin=$(mysql --protocol=socket -uroot -N -B -e \
    "SELECT plugin FROM mysql.user WHERE User='root' AND Host='localhost';" 2>/dev/null || true)

  local pw_sql="${root_pw//\'/\'\'}"
  local mysql_cmd
  if [[ "$auth_plugin" == "auth_socket" || "$auth_plugin" == "unix_socket" ]]; then
    log_info "Switching root auth to mysql_native_password + hardening..."
    mysql_cmd=(mysql --protocol=socket -uroot)
  else
    log_info "Root auth already password-based — updating password + hardening..."
    if ! mysql -uroot -p"$root_pw" -e 'SELECT 1' >/dev/null 2>&1; then
      log_warn "Cannot authenticate with provided password — reset root manually."
      log_cred "MySQL root password (INTENDED, not applied)" "$root_pw"
      return 1
    fi
    mysql_cmd=(mysql -uroot -p"$root_pw")
  fi

  "${mysql_cmd[@]}" <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${pw_sql}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
SQL

  log_cred "MySQL root password" "$root_pw"
}

module_php() {
  pkg_install software-properties-common ca-certificates lsb-release apt-transport-https
  if ! grep -rqs 'ondrej/php' /etc/apt/sources.list /etc/apt/sources.list.d/; then
    add-apt-repository -y ppa:ondrej/php
  fi
  apt-get update -y

  local versions
  versions=$(apt-cache pkgnames 2>/dev/null \
    | grep -E '^php[0-9]+\.[0-9]+-fpm$' \
    | sed -E 's/^php([0-9]+\.[0-9]+)-fpm$/\1/' \
    | sort -Vr \
    | uniq)

  if [[ -z "$versions" ]]; then
    log_error "No php*-fpm packages found via apt-cache."
    return 1
  fi

  local chosen
  chosen=$(printf '%s\n' "$versions" | fzf \
    --height=40% \
    --layout=reverse \
    --border \
    --prompt="php version> " \
    --header="Enter: confirm") || {
    log_warn "PHP version selection cancelled."
    return 1
  }
  if [[ -z "$chosen" ]]; then
    log_error "No PHP version selected."
    return 1
  fi

  local V="$chosen"
  log_info "Installing PHP $V ..."
  pkg_install \
    "php$V" "php$V-fpm" "php$V-redis" "php$V-dev" "php$V-curl" \
    "php$V-gd" "php$V-intl" "php$V-mysql" "php$V-mbstring" \
    "php$V-xml" "php$V-bcmath" "php$V-memcached" "php$V-zip" \
    "php$V-gmp" "php$V-sockets" "php$V-pcntl" php-redis

  local ini
  for ini in "/etc/php/$V/cli/php.ini" "/etc/php/$V/fpm/php.ini"; do
    [[ -f "$ini" ]] || continue
    sed -i -E 's/^;?\s*opcache\.enable\s*=.*/opcache.enable=1/' "$ini"
    sed -i -E 's/^;?\s*opcache\.enable_cli\s*=.*/opcache.enable_cli=1/' "$ini"
    grep -qE '^opcache\.enable=1' "$ini"      || echo 'opcache.enable=1'      >> "$ini"
    grep -qE '^opcache\.enable_cli=1' "$ini"  || echo 'opcache.enable_cli=1'  >> "$ini"
  done

  cat > "/etc/php/$V/mods-available/opcache.ini" <<'OPC'
zend_extension=opcache.so

opcache.enable=1
; enable_cli=1 is REQUIRED for Laravel Octane / RoadRunner / any long-lived CLI worker.
opcache.enable_cli=1

opcache.jit=1255
opcache.jit_buffer_size=128M
opcache.jit_debug=0

opcache.memory_consumption=256
opcache.interned_strings_buffer=32
opcache.max_accelerated_files=20000

opcache.validate_timestamps=0
opcache.revalidate_freq=0

opcache.save_comments=1
opcache.fast_shutdown=1
opcache.enable_file_override=0
OPC

  systemctl restart "php$V-fpm"
  log_cred "PHP version" "$V"
}

module_composer() {
  if require_cmd composer; then
    log_info "composer already installed — skipping."
    return 0
  fi
  pkg_install curl
  if ! require_cmd php; then
    log_error "php is not installed — run the php module first."
    return 1
  fi

  local expected actual tmp=/tmp/composer-setup.php
  log_info "Fetching expected installer signature..."
  if ! expected=$(curl -fsSL https://composer.github.io/installer.sig); then
    log_error "Could not fetch installer signature from composer.github.io."
    return 1
  fi
  if [[ -z "$expected" ]]; then
    log_error "Empty signature received from composer.github.io."
    return 1
  fi

  log_info "Downloading composer installer..."
  if ! curl -fsSL https://getcomposer.org/installer -o "$tmp"; then
    log_error "Could not download installer from getcomposer.org."
    rm -f "$tmp"
    return 1
  fi

  actual=$(php -r "echo hash_file('sha384', '$tmp');")
  if [[ "$expected" != "$actual" ]]; then
    log_error "Composer installer hash mismatch."
    log_error "  expected: $expected"
    log_error "  actual:   $actual"
    rm -f "$tmp"
    return 1
  fi

  if ! php "$tmp" --install-dir=/usr/local/bin --filename=composer; then
    log_error "Composer installer script failed."
    rm -f "$tmp"
    return 1
  fi
  rm -f "$tmp"
}

module_node() {
  # Download the `n` installer and run from disk instead of piping curl into bash.
  if ! require_cmd node; then
    local tmp=/tmp/n-installer.sh
    log_info "Downloading n installer to $tmp ..."
    curl -fsSL https://raw.githubusercontent.com/tj/n/master/bin/n -o "$tmp"
    if ! head -n1 "$tmp" | grep -qE '^#!.*(bash|sh)\b'; then
      log_error "Downloaded n installer does not look like a shell script — aborting."
      rm -f "$tmp"
      return 1
    fi
    bash "$tmp" lts
    rm -f "$tmp"
  else
    log_info "node already present — skipping bootstrap."
  fi
  if ! require_cmd n; then
    npm install -g n
  fi
  if ! require_cmd yarn; then
    npm install --global yarn
  fi
}

module_pm2() {
  if ! require_cmd pm2; then
    npm install -g pm2
  else
    log_info "pm2 already installed — skipping install."
  fi

  # Running pm2 as root is an antipattern — prompt for a dedicated service user.
  local pm2_user default_user="${SUDO_USER:-nodeapp}"
  prompt_line "User to run pm2 under (will be created if missing) [$default_user]" pm2_user
  pm2_user="${pm2_user:-$default_user}"

  if [[ "$pm2_user" == "root" ]]; then
    log_warn "Configuring pm2 as root (not recommended for production)."
  elif ! id -u "$pm2_user" >/dev/null 2>&1; then
    log_info "Creating system user '$pm2_user'..."
    useradd --create-home --shell /bin/bash "$pm2_user"
  fi

  local home_dir
  home_dir=$(getent passwd "$pm2_user" | cut -d: -f6)
  [[ -z "$home_dir" ]] && home_dir="/home/$pm2_user"

  log_info "Configuring pm2 systemd startup for user '$pm2_user' (home: $home_dir)..."
  pm2 startup systemd -u "$pm2_user" --hp "$home_dir" || true

  log_cred "pm2 service user" "$pm2_user"
}

module_aliases() {
  local owner target home_dir
  if [[ -n "${SUDO_USER:-}" ]] && id -u "$SUDO_USER" >/dev/null 2>&1; then
    owner="$SUDO_USER"
  else
    owner="root"
  fi

  home_dir=$(getent passwd "$owner" | cut -d: -f6)
  if [[ -z "$home_dir" ]]; then
    log_error "Could not resolve home directory for user '$owner'."
    return 1
  fi
  if [[ ! -d "$home_dir" ]]; then
    log_error "Home directory '$home_dir' does not exist for user '$owner'."
    return 1
  fi

  target="$home_dir/.bash_aliases"
  local marker='# configure-server aliases'

  if [[ -f "$target" ]] && grep -qF "$marker" "$target"; then
    log_info "Aliases already installed in $target — skipping."
    return 0
  fi

  log_info "Installing aliases into $target (owner: $owner)..."
  cat >> "$target" <<'ALIASES'

# configure-server aliases
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
ALIASES

  if [[ "$owner" != "root" ]]; then
    local group
    group=$(id -gn "$owner" 2>/dev/null || echo "$owner")
    if ! chown "$owner:$group" "$target"; then
      log_warn "chown $owner:$group $target failed — aliases file written but ownership not changed."
    fi
  fi
}

module_ssh_keygen() {
  local target_user="${SUDO_USER:-root}"
  log_info "Running ssh-keygen for user '$target_user' (interactive prompts follow)..."
  sudo -u "$target_user" ssh-keygen
}

main() {
  require_root

  # Re-attach stdin to the controlling terminal so `whiptail` and `read` work
  # even when the script is launched via `curl ... | sudo bash`.
  if [[ ! -t 0 && -r /dev/tty ]]; then
    exec </dev/tty
  fi

  log_info "Updating apt index..."
  apt-get update -y
  ensure_fzf

  local selected
  selected=$(select_modules)
  [[ -z "$selected" ]] && { log_warn "Nothing selected."; exit 0; }

  local entry id
  for entry in "${MODULES[@]}"; do
    id="${entry%%|*}"
    if grep -qx "$id" <<<"$selected"; then
      set +e
      run_module "$id"
      set -e
    fi
  done

  print_summary
}

main "$@"
