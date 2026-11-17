#!/usr/bin/env bash
# CORE-only native installation of DigitalHouses Stats. Existing stats history is not imported.
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
umask 077
[[ "$(id -u)" == 0 ]] || exit 2
[[ "$(hostname -s)" == 'dh-stats-CORE' ]] || { echo CORE60_WRONG_GUEST >&2; exit 2; }
[[ "$(hostname -I)" == *'192.168.11.245'* ]] || { echo CORE60_WRONG_IP >&2; exit 2; }

apt-get update -o APT::Update::Error-Mode=any
apt-get install -y --no-install-recommends ca-certificates curl git python3-venv python3-pip postgresql postgresql-client nginx openssl
systemctl enable --now postgresql

APP_REPO=/opt/digitalhouses/home-assistant-apps
APP_SOURCE="$APP_REPO/digitalhouses-stats"
APP=/opt/digitalhouses/digitalhouses-stats
install -d -m 0755 /opt/digitalhouses
if [[ ! -d "$APP_REPO/.git" ]]; then
  git clone --depth 1 --single-branch --branch main https://github.com/DigitalHouses/home-assistant-apps.git "$APP_REPO"
else
  git -C "$APP_REPO" pull --ff-only
fi
[[ -f "$APP_SOURCE/alembic.ini" && -f "$APP_SOURCE/deploy/digitalhouses-stats.service" ]] || { echo CORE60_INVALID_SOURCE >&2; exit 2; }

install -d -m 0755 "$APP"
cp -a "$APP_SOURCE/." "$APP/"

if ! id digitalhouses-stats >/dev/null 2>&1; then
  useradd --system --home-dir "$APP" --shell /usr/sbin/nologin digitalhouses-stats
fi
install -d -o digitalhouses-stats -g digitalhouses-stats -m 0750 /var/lib/digitalhouses-stats
install -d -o root -g root -m 0700 /etc/digitalhouses-stats

if [[ ! -s /etc/digitalhouses-stats/digitalhouses-stats.env ]]; then
  DB_PASSWORD="$(openssl rand -hex 32)"
  if ! runuser -u postgres -- psql -Atc "SELECT 1 FROM pg_roles WHERE rolname = 'digitalhouses_stats'" | grep -qx 1; then
    runuser -u postgres -- psql -v ON_ERROR_STOP=1 -c "CREATE ROLE digitalhouses_stats LOGIN" >/dev/null
  fi
  runuser -u postgres -- psql -v ON_ERROR_STOP=1 -c "ALTER ROLE digitalhouses_stats PASSWORD '$DB_PASSWORD'" >/dev/null
  if ! runuser -u postgres -- psql -Atc "SELECT 1 FROM pg_database WHERE datname = 'digitalhouses_stats'" | grep -qx 1; then
    runuser -u postgres -- createdb --owner digitalhouses_stats digitalhouses_stats
  fi
  printf 'DATABASE_URL=postgresql+psycopg://digitalhouses_stats:%s@127.0.0.1/digitalhouses_stats?client_encoding=utf8\nLOG_LEVEL=INFO\n' "$DB_PASSWORD" > /etc/digitalhouses-stats/digitalhouses-stats.env
  chmod 0600 /etc/digitalhouses-stats/digitalhouses-stats.env
  unset DB_PASSWORD
fi

if [[ ! -x "$APP/.venv/bin/python" ]]; then
  python3 -m venv "$APP/.venv"
fi
"$APP/.venv/bin/pip" install --disable-pip-version-check --no-cache-dir "$APP"
# Sources are public; the dedicated unprivileged systemd account must traverse
# the app and venv directories. Secrets remain outside the app, under /etc.
chmod -R a+rX "$APP"
(
  cd "$APP"
  set -a
  # shellcheck disable=SC1091
  . /etc/digitalhouses-stats/digitalhouses-stats.env
  set +a
  "$APP/.venv/bin/alembic" upgrade head
)

install -o root -g root -m 0644 "$APP/deploy/digitalhouses-stats.service" /etc/systemd/system/digitalhouses-stats.service
install -o root -g root -m 0644 "$APP/deploy/digitalhouses-stats-dashboard-api.service" /etc/systemd/system/digitalhouses-stats-dashboard-api.service

# The upstream dashboard has an old HOME-specific LAN bind. Substitute only in
# the installed CORE nginx config; do not edit the upstream product repository.
grep -q '192.168.11.254:80' "$APP/deploy/nginx-digitalhouses-stats.conf" || { echo CORE60_DASHBOARD_BIND_CHANGED >&2; exit 2; }
sed 's/192\.168\.11\.254:80/192.168.11.245:80/g' "$APP/deploy/nginx-digitalhouses-stats.conf" > /etc/nginx/sites-available/digitalhouses-stats
ln -sfn /etc/nginx/sites-available/digitalhouses-stats /etc/nginx/sites-enabled/digitalhouses-stats
rm -f /etc/nginx/sites-enabled/default
install -d -o root -g root -m 0755 /var/www/digitalhouses-stats
cp -a "$APP/dashboard/." /var/www/digitalhouses-stats/
chmod -R go+rX /var/www/digitalhouses-stats
nginx -t
systemctl daemon-reload
systemctl enable --now digitalhouses-stats digitalhouses-stats-dashboard-api nginx
systemctl restart digitalhouses-stats digitalhouses-stats-dashboard-api nginx

for url in http://127.0.0.1:8080/healthz http://127.0.0.1:8081/healthz http://192.168.11.245/healthz; do
  ready=0
  for attempt in $(seq 1 20); do
    if curl -fsS --max-time 4 "$url" >/dev/null 2>&1; then
      ready=1
      break
    fi
    sleep 1
  done
  [[ $ready == 1 ]] || { echo "CORE60_HEALTH_FAILED=$url" >&2; exit 2; }
done
pg_isready -h 127.0.0.1 -p 5432
runuser -u postgres -- psql -d digitalhouses_stats -Atc 'SELECT COUNT(*) FROM installations;' >/dev/null
runuser -u postgres -- psql -d digitalhouses_stats -Atc 'SELECT COUNT(*) FROM heartbeats;' >/dev/null
printf 'CORE60_INSTALL=PASS\nCORE60_PG_FRESH=EMPTY\nCORE60_DASHBOARD_LAN=192.168.11.245\n'
