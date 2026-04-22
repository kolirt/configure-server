check_redis() { require_cmd redis-server && systemctl is-active --quiet redis-server 2>/dev/null; }

module_redis() {
  pkg_install redis-server
  systemctl enable redis-server.service
  systemctl restart redis-server.service
}
