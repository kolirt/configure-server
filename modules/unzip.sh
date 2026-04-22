check_unzip() { require_cmd unzip; }

module_unzip() {
  if require_cmd unzip; then
    log_info "unzip already present — skipping install."
    return 0
  fi
  pkg_install unzip
}
