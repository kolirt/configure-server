check_node() { require_cmd node && require_cmd yarn && require_cmd n; }

module_node() {
  # Download the `n` installer and run from disk instead of piping curl into bash.
  if ! require_cmd node; then
    local tmp=/tmp/n-installer.sh
    log_info "Downloading n installer to $tmp ..."
    curl -fsSL https://raw.githubusercontent.com/tj/n/master/bin/n -o "$tmp"
    if ! head -n1 "$tmp" | grep -qE '^#!.*(bash|sh)\b'; then
      log_error "Downloaded n installer does not look like a shell script — aborting."
      rm -f "$tmp"
      return 1
    fi
    bash "$tmp" lts
    rm -f "$tmp"
  else
    log_info "node already present — skipping bootstrap."
  fi
  if ! require_cmd n; then
    npm install -g n
  fi
  if ! require_cmd yarn; then
    npm install --global yarn
  fi
}
