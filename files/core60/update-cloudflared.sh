#!/usr/bin/env bash
set -Eeuo pipefail

before="$(dpkg-query -W -f='${Version}' cloudflared)"
apt-get update -qq
apt-get install -y --only-upgrade cloudflared
after="$(dpkg-query -W -f='${Version}' cloudflared)"

if [[ "$after" != "$before" ]]; then
  systemctl restart cloudflared-dh-core.service
fi
