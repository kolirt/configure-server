check_mysql() { require_cmd mysql && systemctl is-active --quiet mysql 2>/dev/null; }

module_mysql() {
  pkg_install mysql-server
  systemctl enable mysql
  systemctl start mysql

  local root_pw
  prompt_secret "New MySQL root password" root_pw

  local auth_plugin
  auth_plugin=$(mysql --protocol=socket -uroot -N -B -e \
    "SELECT plugin FROM mysql.user WHERE User='root' AND Host='localhost';" 2>/dev/null || true)

  local pw_sql="${root_pw//\'/\'\'}"
  local mysql_cmd
  if [[ "$auth_plugin" == "auth_socket" || "$auth_plugin" == "unix_socket" ]]; then
    log_info "Switching root auth to mysql_native_password + hardening..."
    mysql_cmd=(mysql --protocol=socket -uroot)
  else
    log_info "Root auth already password-based — updating password + hardening..."
    if ! mysql -uroot -p"$root_pw" -e 'SELECT 1' >/dev/null 2>&1; then
      log_warn "Cannot authenticate with provided password — reset root manually."
      log_cred "MySQL root password (INTENDED, not applied)" "$root_pw"
      return 1
    fi
    mysql_cmd=(mysql -uroot -p"$root_pw")
  fi

  "${mysql_cmd[@]}" <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${pw_sql}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
SQL

  log_cred "MySQL root password" "$root_pw"
}
