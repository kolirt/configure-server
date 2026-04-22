check_swap() { [[ -n "$(swapon --show --noheadings 2>/dev/null || true)" ]]; }

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
