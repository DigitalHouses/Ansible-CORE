#!/usr/bin/env bash
# Dedicated CORE LAN origin for CF connector; protected upstream stays loopback.
set -Eeuo pipefail
[[ $(id -u) == 0 ]] || exit 2
[[ $(hostname -s) == dh-stats-CORE ]] || exit 2
[[ " $(hostname -I) " == *' 192.168.11.245 '* ]] || exit 2
[[ -f /etc/nginx/sites-available/digitalhouses-stats ]] || exit 2
cat > /etc/nginx/sites-available/dh-stats-network-origin <<'NGINX'
server {
    listen 192.168.11.245:8082;
    server_name _;
    server_tokens off;
    access_log off;

    location / {
        # The cloudflared connector runs in this same CT. Other LAN guests
        # cannot bypass Cloudflare to forge CF-IPCountry.
        allow 192.168.11.245;
        allow 127.0.0.1;
        deny all;
        proxy_http_version 1.1;
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header Connection "";
        proxy_read_timeout 15s;
    }
}
NGINX
chmod 0644 /etc/nginx/sites-available/dh-stats-network-origin
ln -sfn /etc/nginx/sites-available/dh-stats-network-origin /etc/nginx/sites-enabled/dh-stats-network-origin
nginx -t
systemctl reload nginx
for attempt in $(seq 1 15); do
  if curl --noproxy '*' -fsS --max-time 3 http://192.168.11.245:8082/healthz | grep -q '"ok"'; then
    echo 'CORE60_NETWORK_ORIGIN=PASS'
    echo 'CORE60_NETWORK_ORIGIN_URL=http://192.168.11.245:8082'
    exit 0
  fi
  sleep 1
done
echo CORE60_NETWORK_ORIGIN_FAILED >&2
exit 2
