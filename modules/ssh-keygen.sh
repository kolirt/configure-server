check_ssh_keygen() {
  local owner home_dir
  owner="${SUDO_USER:-root}"
  home_dir=$(getent passwd "$owner" | cut -d: -f6)
  [[ -n "$home_dir" ]] && \
    compgen -G "$home_dir/.ssh/id_*" >/dev/null
}

module_ssh_keygen() {
  local target_user="${SUDO_USER:-root}"
  log_info "Running ssh-keygen for user '$target_user' (interactive prompts follow)..."
  sudo -u "$target_user" ssh-keygen
}
