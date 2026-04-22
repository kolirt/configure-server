check_certbot() { require_cmd certbot && crontab -l 2>/dev/null | grep -qF 'certbot renew'; }

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
