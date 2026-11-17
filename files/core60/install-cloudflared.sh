#!/usr/bin/env bash
set -Eeuo pipefail
[[ "$(id -u)" == 0 && -s /etc/cloudflared/token ]] || { echo CORE60_CLOUDFLARED_TOKEN_ABSENT >&2; exit 2; }
[[ "$(hostname -s)" == 'dh-stats-CORE' ]] || exit 2

# Package-managed cloudflared: use the same Debian unattended-upgrades as HOME.
install -d -m 0755 /usr/share/keyrings
curl -fsSL --retry 3 --max-time 120 https://pkg.cloudflare.com/cloudflare-main.gpg -o /usr/share/keyrings/cloudflare-main.gpg
chmod 0644 /usr/share/keyrings/cloudflare-main.gpg
printf '%s\n' 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' > /etc/apt/sources.list.d/cloudflared.list

if ! command -v cloudflared >/dev/null 2>&1; then
  apt-get update -qq
  apt-get install -y cloudflared
fi

install -o root -g root -m 0644 /root/cloudflared-unattended.conf /etc/apt/apt.conf.d/90-dh-cloudflared-unattended
apt-get update -qq
apt-get install -y unattended-upgrades

# Retire the former standalone timer if a previous CORE deployment installed it.
if [[ -f /etc/systemd/system/cloudflared-dh-core-update.timer ]]; then
  systemctl disable --now cloudflared-dh-core-update.timer
fi
rm -f /etc/systemd/system/cloudflared-dh-core-update.timer /etc/systemd/system/cloudflared-dh-core-update.service /usr/local/sbin/core60-update-cloudflared

install -o root -g root -m 0644 /root/cloudflared-dh-core.service /etc/systemd/system/cloudflared-dh-core.service
systemctl daemon-reload
systemctl enable --now cloudflared-dh-core.service
systemctl enable --now apt-daily.timer apt-daily-upgrade.timer

systemctl is-active --quiet cloudflared-dh-core.service
systemctl is-active --quiet apt-daily.timer
systemctl is-active --quiet apt-daily-upgrade.timer

policy="$(apt-config dump)"
for expected in \
  'Unattended-Upgrade::Package-Whitelist-Strict "true";' \
  'Unattended-Upgrade::Automatic-Reboot "false";' \
  'APT::Periodic::Unattended-Upgrade "1";' \
  'APT::Periodic::Update-Package-Lists "1";' \
  'origin=cloudflared,site=pkg.cloudflare.com' \
  '^cloudflared$'; do
  grep -Fq "$expected" <<< "$policy" || { echo CORE60_CLOUDFLARED_APT_POLICY_INVALID >&2; exit 2; }
done

timeout 180 unattended-upgrade --dry-run --debug >/dev/null
printf 'CORE60_CLOUDFLARED=RUNNING; AUTO_UPDATE=UNATTENDED_UPGRADES; REBOOT=DISABLED\n'
