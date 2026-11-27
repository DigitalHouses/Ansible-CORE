#!/usr/bin/env bash
# Update only DH Stats application/dashboard on existing CORE CT1245.
# Preserve PostgreSQL history, Cloudflare Tunnel, DNS, and every other product.
set -Eeuo pipefail
[[ $(id -u) -eq 0 ]] || exit 2
[[ $(hostname -s) == 'dh-stats-CORE' ]] || { echo CORE60_WRONG_HOST; exit 2; }
[[ " $(hostname -I) " == *' 192.168.11.245 '* ]] || { echo CORE60_WRONG_ADDRESS; exit 2; }

REPO=/opt/digitalhouses/home-assistant-apps
SRC="$REPO/digitalhouses-stats"
APP=/opt/digitalhouses/digitalhouses-stats
WEB=/var/www/digitalhouses-stats
[[ -d "$REPO/.git" && -d "$APP/digitalhouses_stats" && -d "$WEB/assets" ]] || {
  echo CORE60_STATS_INSTALLATION_INCOMPLETE; exit 2;
}

git -C "$REPO" pull --ff-only origin main

# A new telemetry product is registered in the upstream canonical catalog.
# Do not accept a deploy where the runtime catalog is stale or malformed.
python3 - "$SRC/digitalhouses_stats/product_registry.json" <<'REGISTRY'
import json
import sys
from pathlib import Path
catalog = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert catalog.get("schema") == 1, "CORE60_REGISTRY_SCHEMA_INVALID"
products = catalog.get("products")
assert isinstance(products, list) and products, "CORE60_REGISTRY_EMPTY"
ids = [p["id"] for p in products]
assert len(ids) == len(set(ids)), "CORE60_REGISTRY_DUPLICATE_ID"
assert all(isinstance(p.get("telemetry_allowed"), bool) for p in products), "CORE60_REGISTRY_POLICY_INVALID"
print(f"CORE60_UPSTREAM_PRODUCT_COUNT={len(ids)}")
REGISTRY
[[ -f "$SRC/digitalhouses_stats/stats.py" && -f "$SRC/dashboard/assets/app.js" ]] || exit 2

# Product-only files; leave DB credentials, schema and runtime dependencies untouched.
cp -a "$SRC/digitalhouses_stats/." "$APP/digitalhouses_stats/"
cp -a "$SRC/dashboard/." "$WEB/"
cp -a "$SRC/dashboard/." "$APP/dashboard/"
cp -a "$SRC/VERSION" "$APP/VERSION"
cp -a "$SRC/pyproject.toml" "$APP/pyproject.toml"
chmod -R a+rX "$APP" "$WEB"

# Both services must import the deployed sources, not an older venv wheel.
for svc in digitalhouses-stats digitalhouses-stats-dashboard-api; do
  install -d -m 0755 "/etc/systemd/system/$svc.service.d"
  printf '[Service]\nEnvironment=PYTHONPATH=%s\n' "$APP" > "/etc/systemd/system/$svc.service.d/20-local-source.conf"
done
systemctl daemon-reload

# Installation is a local package copy, but both processes cache the allowlist
# at import time. Restart and verify exact parity with the checked-out registry.
systemctl restart digitalhouses-stats-dashboard-api digitalhouses-stats
python3 - "$SRC/digitalhouses_stats/product_registry.json" "$APP/.venv/bin/python" <<'REGISTRY_CHECK'
import json
import subprocess
import sys
from pathlib import Path
catalog = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
expected = {p["id"] for p in catalog["products"] if p["telemetry_allowed"]}
script = "import json; from digitalhouses_stats.products import ALLOWED_PRODUCTS; print(json.dumps(sorted(ALLOWED_PRODUCTS)))"
app = str(Path(sys.argv[2]).parent.parent.parent)
actual = set(json.loads(subprocess.check_output(["runuser", "-u", "digitalhouses-stats", "--", "env", f"PYTHONPATH={app}", sys.argv[2], "-c", script], cwd=app, text=True)))
assert actual == expected, f"CORE60_REGISTRY_MISMATCH missing={sorted(expected - actual)} unexpected={sorted(actual - expected)}"
print(f"CORE60_REGISTRY_SYNC=PASS allowed={len(actual)}")
REGISTRY_CHECK
for url in http://127.0.0.1:8080/healthz http://127.0.0.1:8081/healthz http://192.168.11.245/healthz; do
  ready=0
  for attempt in $(seq 1 15); do
    if curl --noproxy '*' -fsS --max-time 3 "$url" >/dev/null 2>&1; then
      ready=1; break
    fi
    sleep 1
  done
  [[ $ready == 1 ]] || { echo "CORE60_UPDATE_HEALTH_FAILED=$url"; exit 2; }
done

# Verify the actual running dashboard API, not only a root Python import.
python3 - "$SRC/digitalhouses_stats/product_registry.json" <<'API_REGISTRY'
import json
import sys
import urllib.request
expected = {p["id"] for p in json.load(open(sys.argv[1]))["products"]}
with urllib.request.urlopen("http://127.0.0.1:8081/v1/stats/products", timeout=8) as response:
    actual = {p["product"] for p in json.load(response)}
assert actual == expected, f"CORE60_DASHBOARD_CATALOG_MISMATCH missing={sorted(expected-actual)} unexpected={sorted(actual-expected)}"
print("CORE60_DASHBOARD_CATALOG=PASS")
API_REGISTRY

# Read-only E2E contract: every country counter sums its product counters.
python3 - <<'PY'
import json
import urllib.request
url = "http://192.168.11.245/api/countries"
with urllib.request.urlopen(url, timeout=8) as response:
    rows = json.load(response)
assert isinstance(rows, list)
for country in rows:
    items = country["products"]
    assert items, f"country {country['country']} has no product breakdown"
    for item in items:
        assert item["name"] and item["product"]
    for field in ("observed_installations", "active_7d", "active_30d"):
        assert sum(product[field] for product in items) == country[field], field
print(f"CORE60_COUNTRY_PRODUCT_COUNTS=PASS countries={len(rows)}")
PY
python3 - <<'PY2'
import urllib.request
for address, marker in (
    ('http://192.168.11.245/', 'Click a country to see apps and agents'),
    ('http://192.168.11.245/assets/app.js?v=country-products', 'renderCountries'),
):
    with urllib.request.urlopen(address, timeout=8) as response:
        assert marker in response.read().decode('utf-8')
print('CORE60_COUNTRY_DASHBOARD_ASSETS=PASS')
PY2

echo CORE60_STATS_UPDATE=PASS
echo "CORE60_STATS_VERSION=$(cat "$APP/VERSION")"
echo CORE60_STATS_COUNTRY_EXPANSION=ENABLED
