check_git() { require_cmd git; }

module_git() {
  if require_cmd git; then
    log_info "git already present — skipping install."
    return 0
  fi
  pkg_install git
}
