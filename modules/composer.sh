check_composer() { require_cmd composer; }

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
