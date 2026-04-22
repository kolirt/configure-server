check_pm2() { require_cmd pm2 && systemctl list-unit-files 2>/dev/null | grep -qE '^pm2-[^ ]+\.service'; }

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
