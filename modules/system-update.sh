module_system_update() {
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
}
