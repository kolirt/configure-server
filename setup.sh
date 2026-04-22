#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Order here is the execution order, and the order shown in the fzf menu.
readonly MODULES=(
  "system-update|System update (apt update && upgrade)"
  "swap|Swap file (auto-sized)"
  "git|git"
  "unzip|unzip"
  "nginx|nginx + default config"
  "nginx-basic-auth|nginx basic auth (htpasswd)"
  "certbot|Let's Encrypt (certbot)"
  "redis|Redis"
  "mysql|MySQL server"
  "php|PHP (version picked interactively)"
  "composer|Composer"
  "node|Node.js + n + yarn"
  "pm2|pm2"
  "aliases|bash aliases"
  "ssh-keygen|ssh-keygen"
)

# Source a module file by id. Modules define module_<id> (and optionally
# check_<id>) into the current shell.
load_module() {
  local id="$1" file="$SCRIPT_DIR/modules/$id.sh"
  if [[ ! -f "$file" ]]; then
    log_error "Module file missing: $file"
    return 1
  fi
  # shellcheck disable=SC1090
  source "$file"
}

select_modules() {
  local -a lines=()
  local entry id desc status
  for entry in "${MODULES[@]}"; do
    id="${entry%%|*}"
    desc="${entry#*|}"
    # check_<id> may live in the module file — load it first so we can ask.
    load_module "$id" >/dev/null 2>&1 || true
    if is_module_done "$id"; then
      status="[x]"
    else
      status="[ ]"
    fi
    lines+=("$(printf '%s\t%s\t%s' "$status" "$id" "$desc")")
  done

  log_info "Opening module picker (${#lines[@]} modules)..." >&2

  local selection fzf_rc=0
  selection=$(printf '%s\n' "${lines[@]}" | fzf \
    --multi \
    --height=80% \
    --layout=reverse \
    --border \
    --delimiter=$'\t' \
    --with-nth=1,2,3 \
    --prompt="modules> " \
    --header="Tab: toggle   Enter: confirm   Ctrl-A: select all   Ctrl-D: deselect all   [x] = already configured" \
    --bind="ctrl-a:select-all,ctrl-d:deselect-all") || fzf_rc=$?

  if (( fzf_rc == 130 )); then
    log_warn "Selection cancelled (Esc / Ctrl-C)."
    exit 0
  fi
  if (( fzf_rc != 0 )); then
    log_error "fzf exited with code $fzf_rc."
    exit 1
  fi
  if [[ -z "$selection" ]]; then
    log_warn "No modules selected (use Tab or Ctrl-A to mark items before Enter)."
    exit 0
  fi

  awk -F'\t' '{print $2}' <<<"$selection"
}

main() {
  require_root

  # Re-attach stdin to the controlling terminal so fzf and `read` work
  # even when the script is launched via `curl ... | sudo bash`.
  if [[ ! -t 0 && -r /dev/tty ]]; then
    exec </dev/tty
  fi

  log_info "Updating apt index..."
  apt-get update -y
  ensure_fzf

  local selected
  selected=$(select_modules)
  [[ -z "$selected" ]] && { log_warn "Nothing selected."; exit 0; }

  local entry id
  for entry in "${MODULES[@]}"; do
    id="${entry%%|*}"
    if grep -qx "$id" <<<"$selected"; then
      load_module "$id"
      set +e
      run_module "$id"
      set -e
    fi
  done

  print_summary
}

main "$@"
