#!/usr/bin/env bash
set -Eeuo pipefail
[[ "$(id -u)" == 0 && -s /etc/cloudflared/token ]] || { echo CORE60_CLOUDFLARED_TOKEN_ABSENT >&2; exit 2; }
[[ "$(hostname -s)" == 'dh-stats-CORE' ]] || exit 2
if ! command -v cloudflared >/dev/null 2>&1; then
  curl -fsSL --retry 3 --max-time 120 https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /root/cloudflared-linux-amd64.deb
  apt-get install -y /root/cloudflared-linux-amd64.deb
  rm -f /root/cloudflared-linux-amd64.deb
fi
install -o root -g root -m 0644 /root/cloudflared-dh-core.service /etc/systemd/system/cloudflared-dh-core.service
systemctl daemon-reload
systemctl enable --now cloudflared-dh-core.service
systemctl is-active --quiet cloudflared-dh-core.service
printf 'CORE60_CLOUDFLARED=RUNNING\n'
