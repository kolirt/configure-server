# configure-server

Interactive bash script for provisioning a fresh Ubuntu 22.04 / 24.04 server for a PHP backend (Laravel Octane + RoadRunner, classic FPM sites, Node services, etc.).

## Run

On a fresh Ubuntu server:

```bash
curl -fsSL https://raw.githubusercontent.com/kolirt/configure-server/master/setup.sh | sudo bash
```

## What it does

Prints a numbered list of modules, reads your selection (e.g. `1 2 5 9` or `all`), then runs the chosen modules in canonical order. Sensitive values (passwords, domains, service users) are prompted inline. At the end the script prints a credentials block — **save it immediately**, nothing is persisted to disk.

Modules:

| ID | Description |
|---|---|
| `system-update` | `apt update && upgrade` |
| `swap` | Swap file, size auto-computed per the Ubuntu recommendation |
| `git` | git |
| `unzip` | unzip |
| `nginx` | nginx with production defaults (`worker_connections`, `server_tokens off`, timeouts, gzip) |
| `nginx-basic-auth` | `apache2-utils` + `.htpasswd` |
| `certbot` | Let's Encrypt + cron entry for auto-renewal |
| `redis` | redis-server |
| `mysql` | mysql-server + full `mysql_secure_installation` equivalent |
| `php` | PHP (version picked from `apt-cache` after adding `ppa:ondrej/php`) + opcache with JIT, extensions for Octane / RoadRunner (`sockets`, `pcntl`, `redis`, etc.) |
| `composer` | composer (with live sha384 verification of the installer) |
| `node` | Node.js LTS via `n` + yarn |
| `pm2` | pm2 with systemd startup under a dedicated service user |
| `aliases` | bash aliases for `cd ../` and `switch-php` |
| `ssh-keygen` | SSH key for the invoking user |

## After running

- Re-enter the shell (`exec bash`) so `.bash_aliases` and the `composer` / `node` / `pm2` PATH entries are picked up.
- Install firewall (`ufw`), fail2ban, and SSH hardening separately — they are not part of this script.
- For Laravel Octane + RoadRunner: the RoadRunner binary is installed per-app via `composer require spiral/roadrunner-cli && ./vendor/bin/rr get`. A systemd unit or pm2 config for `octane:start --server=roadrunner` is also per-app.

## Running in tmux

If the SSH session may drop:

```bash
tmux new -s setup
curl -fsSL https://raw.githubusercontent.com/kolirt/configure-server/master/setup.sh | sudo bash
# detach: Ctrl+b d
# reattach: tmux attach -t setup
```
