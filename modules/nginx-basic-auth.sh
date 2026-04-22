check_nginx_basic_auth() { [[ -f /etc/nginx/.htpasswd ]] && require_cmd htpasswd; }

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
