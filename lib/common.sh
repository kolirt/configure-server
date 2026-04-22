readonly C_RESET=$'\033[0m'
readonly C_INFO=$'\033[1;34m'
readonly C_WARN=$'\033[1;33m'
readonly C_ERR=$'\033[1;31m'
readonly C_OK=$'\033[1;32m'

declare -a CREDENTIALS_LOG=()
declare -a INSTALLED=()
declare -a FAILED=()
declare -a SKIPPED=()

log_info()  { printf '%s[INFO]%s %s\n'  "$C_INFO" "$C_RESET" "$*"; }
log_warn()  { printf '%s[WARN]%s %s\n'  "$C_WARN" "$C_RESET" "$*" >&2; }
log_error() { printf '%s[ERR ]%s %s\n'  "$C_ERR"  "$C_RESET" "$*" >&2; }
log_ok()    { printf '%s[ OK ]%s %s\n'  "$C_OK"   "$C_RESET" "$*"; }

log_cred() { CREDENTIALS_LOG+=("$1: $2"); }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)."
    exit 1
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1
}

pkg_install() {
  DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

# Dispatch to per-module check function: returns 0 if the module looks already
# configured on this host, 1 otherwise. Modules without a check are never
# considered done (always re-runnable).
is_module_done() {
  local id="$1" fn="check_${1//-/_}"
  if declare -F "$fn" >/dev/null; then
    "$fn"
  else
    return 1
  fi
}

ensure_fzf() {
  if ! require_cmd fzf; then
    log_info "Installing fzf..."
    pkg_install fzf
  fi
}

prompt_secret() {
  local label="$1" out_var="$2" p1 p2
  while true; do
    read -rsp "$label: " p1; echo
    read -rsp "$label (confirm): " p2; echo
    if [[ "$p1" == "$p2" && -n "$p1" ]]; then
      printf -v "$out_var" '%s' "$p1"
      return 0
    fi
    log_warn "Values do not match or are empty. Try again."
  done
}

prompt_line() {
  local label="$1" out_var="$2" val
  read -rp "$label: " val
  printf -v "$out_var" '%s' "$val"
}

compute_swap_gb() {
  local kb gb
  kb=$(awk '/MemTotal/{print $2}' /proc/meminfo)
  gb=$(( (kb + 1048575) / 1048576 ))
  if   (( gb <= 2 ));  then echo $(( gb * 2 ))
  elif (( gb <= 8 ));  then echo "$gb"
  elif (( gb <= 64 )); then
    local half=$(( gb / 2 ))
    (( half < 4 )) && half=4
    echo "$half"
  else
    echo 4
  fi
}

run_module() {
  local id="$1" fn="module_${1//-/_}"
  if ! declare -F "$fn" >/dev/null; then
    log_error "No implementation for module '$id' (function $fn missing)."
    FAILED+=("$id")
    return 0
  fi
  if is_module_done "$id"; then
    log_info "=== Skipping: $id (already configured) ==="
    SKIPPED+=("$id")
    return 0
  fi
  log_info "=== Running: $id ==="
  if "$fn"; then
    INSTALLED+=("$id")
    log_ok "=== Done: $id ==="
  else
    log_warn "=== Failed: $id (continuing) ==="
    FAILED+=("$id")
  fi
}

print_summary() {
  echo
  echo "============================================================="
  echo " configure-server setup complete"
  echo "-------------------------------------------------------------"
  if ((${#INSTALLED[@]})); then
    echo " Installed: ${INSTALLED[*]}"
  fi
  if ((${#SKIPPED[@]})); then
    echo " Skipped:   ${SKIPPED[*]} (already completed previously)"
  fi
  if ((${#FAILED[@]})); then
    echo " Failed:    ${FAILED[*]}"
  fi
  echo "-------------------------------------------------------------"
  if ((${#CREDENTIALS_LOG[@]})); then
    echo " Credentials (save these — not persisted anywhere):"
    local line
    for line in "${CREDENTIALS_LOG[@]}"; do
      echo "   $line"
    done
  else
    echo " No credentials were captured."
  fi
  echo "============================================================="
}
