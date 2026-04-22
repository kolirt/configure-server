check_php() { require_cmd php && php -v 2>/dev/null | grep -qE '^PHP [0-9]+\.[0-9]+'; }

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
  # Note: `sockets` and `pcntl` extensions are bundled with the main phpX.Y
  # package in ondrej/php, no separate packages exist.
  if ! pkg_install \
    "php$V" "php$V-fpm" "php$V-redis" "php$V-dev" "php$V-curl" \
    "php$V-gd" "php$V-intl" "php$V-mysql" "php$V-mbstring" \
    "php$V-xml" "php$V-bcmath" "php$V-memcached" "php$V-zip" \
    "php$V-gmp" php-redis; then
    log_error "Failed to install PHP $V packages."
    return 1
  fi

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
