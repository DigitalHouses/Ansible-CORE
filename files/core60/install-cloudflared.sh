#!/usr/bin/env bash
set -Eeuo pipefail
[[ "$(id -u)" == 0 && -s /etc/cloudflared/token ]] || { echo CORE60_CLOUDFLARED_TOKEN_ABSENT >&2; exit 2; }
[[ "$(hostname -s)" == 'dh-stats-CORE' ]] || exit 2

# cloudflared is installed via APT: native --autoupdate-freq does not apply.
install -d -m 0755 /usr/share/keyrings
curl -fsSL --retry 3 --max-time 120 https://pkg.cloudflare.com/cloudflare-main.gpg -o /usr/share/keyrings/cloudflare-main.gpg
chmod 0644 /usr/share/keyrings/cloudflare-main.gpg
printf '%s\n' 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' > /etc/apt/sources.list.d/cloudflared.list
if ! command -v cloudflared >/dev/null 2>&1; then
  apt-get update -qq
  apt-get install -y cloudflared
fi

install -o root -g root -m 0755 /root/core60-update-cloudflared.sh /usr/local/sbin/core60-update-cloudflared
install -o root -g root -m 0644 /root/cloudflared-dh-core.service /etc/systemd/system/cloudflared-dh-core.service
install -o root -g root -m 0644 /root/cloudflared-dh-core-update.service /etc/systemd/system/cloudflared-dh-core-update.service
install -o root -g root -m 0644 /root/cloudflared-dh-core-update.timer /etc/systemd/system/cloudflared-dh-core-update.timer
systemctl daemon-reload
systemctl enable --now cloudflared-dh-core.service
systemctl enable --now cloudflared-dh-core-update.timer
systemctl is-active --quiet cloudflared-dh-core.service
systemctl is-active --quiet cloudflared-dh-core-update.timer
printf 'CORE60_CLOUDFLARED=RUNNING; AUTO_UPDATE=DAILY\n'
