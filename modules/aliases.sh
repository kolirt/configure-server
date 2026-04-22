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
