# №60 — CORE DH Stats: диагностика и план переноса

**Новая цель (17.11.2026):** чистая CORE установка без истории HOME. Отдельный новый Tunnel `dh-core`; действующий HOME Tunnel и DNS не меняются до успешной локальной установки и готовности connector.

## Подтверждённый исходный контракт

- Продукт: `DigitalHouses/home-assistant-apps/digitalhouses-stats`.
- Исходный сервер по старой документации: HOME CT7000 `digitalhouses-stats`, IP `192.168.11.254` **исторический**, на 16.11.2026 актуальный IP CT7000 не подтверждён. Адрес `.254` теперь занимает DEV CT1254, поэтому нельзя копировать старую IP-конфигурацию в CORE.
- Public HTTPS: `https://telemetry.digitalhouses.vip`; `GET /healthz` возвращает `200 {"status":"ok"}` при проверке из DEV 16.11.2026.
- Приём: FastAPI/systemd `127.0.0.1:8080`, `POST /v1/heartbeat`, `DELETE /v1/installation`, доверенный Cloudflare `CF-IPCountry`.
- Dashboard: **только LAN**, nginx `:80` + отдельная FastAPI `127.0.0.1:8081`. В исходном скрипте и nginx hardcoded `192.168.11.254`, требуется параметризация.
- Хранилище: PostgreSQL в том же LXC (`digitalhouses_stats`, `installations` и append-only `heartbeats`), история с HOME **не переносится** по решению владельца. Новая схема создаётся `alembic upgrade head`.
- Cloudflare origin и конкретный Tunnel сейчас **не подтверждены из Cloudflare API**. Публичное здоровье доказывает доступность сервиса, но не путь до CT7000.

## Кандидат CORE

- PVE `192.168.11.240`, CT **1245**; IP **192.168.11.245/24**; PVE имя **`dh-stats-CORE`** (строгий суффикс `-CORE`). Это кандидат, занятость проверяет №60 audit. IP проверяется ARP duplicate-address-detection на CORE PVE перед созданием; 16.11.2026 #148 показал `CLEAR_BY_ARPING_DAD`.
- Debian LXC, один сервис с локальным PostgreSQL, без зависимости от HOME/VM2243 и без отдельной Stats-базы на CT1244. Начальные ресурсы по проекту: 1 vCPU, 1 ГиБ RAM, 16 ГиБ SSD — уточнить по фактическому размеру текущей БД перед `apply`.
- **Тот же** публичный домен `telemetry.digitalhouses.vip`; никаких изменений в коде клиентов `dh_ha_apps`.
- Cloudflared/Tunnel cutover должен сохранить защиту: приложение принимает `CF-IPCountry` только от доверенного Cloudflare ingress, прямой интернет-доступ до `:8080` не допускается. Локальный dashboard не должен публиковаться через публичный путь.
- Существующий CORE nightly PVE backup job `dh-core-pbs-daily` захватывает новый CT по `all=1` (исключение VM2243), но до завершения переноса нужен отдельный PostgreSQL dump/restore с проверкой.

## Выполненная CORE диагностика — 16.11.2026

CORE Semaphore №00 Job #144 зарегистрировал новый шаблон №60 (ID 8).
CORE Semaphore №60 Job **#145** — **Success, changed=0**, исключительно чтение:

- PVE: `pve`, адрес `192.168.11.240/24`, идентичность подтверждена.
- `CORE60_TARGET_CTID=1245`, `CORE60_TARGET_LABEL=dh-stats-CORE`, `CORE60_TARGET_IPV4=192.168.11.245`.
- `CORE60_CTID=AVAILABLE_IN_PVE`, `CORE60_PVE_NAME=AVAILABLE_IN_PVE`.
- `CORE60_PUBLIC_TELEMETRY=HEALTHY` (`/healthz`: HTTP 200 с `status=ok`).
- `CORE60_CF_ORIGIN=NOT_VERIFIED`, `CORE60_IP_LAN_OCCUPANCY=NOT_VERIFIED_BY_PVE_GUEST_IDS`.
- HOME CT7000, базы данных, Cloudflare Tunnel, PVE guests не изменены.

**Не считать свободный VMID доказательством свободного LAN IP.** Перед apply
требуется надёжная проверка IP на CORE и проверка актуального origin по CF API.

## Порядок выполнения (не стирает старую базу)

1. **№60 `audit`** — IP/CT identity, ARP check, public health.
2. **№60 `cf-audit`** — прочитать CF Zone/DNS/Tunnel; **`prepare-tunnel`** — создать удалённо управляемый `dh-core`, **не менять** DNS. Job #150 создал tunnel `ef829b9e-c410-4b5b-a754-85ab01b9d31b`, старый DNS и HOME не тронуты.
3. **№60 `deploy`** — создать CORE CT1245 на Debian 13, установить PostgreSQL с новой пустой БД и Alembic, Stats ingestion + LAN-only dashboard, запустить внутри CT `cloudflared-dh-core` с root-only токеном. До cutover публичный DNS не меняется. Не переиспользовать данные HOME.
4. После локального и CF connector E2E — переключение **только** `telemetry.digitalhouses.vip` на новый tunnel. Публичный dashboard **не публикуется**, только ingestion API; прежнюю DNS-запись сохранять для возможного отката.
5. Проверить реальный публичный heartbeat и удалить тестовую установку; копии CT1245 идут в действующий CORE PBS `pbs-core/dh-core`.

Статус текущих действий и job ID фиксируется ниже. Режим `deploy` не удаляет никакой существующий CT, никогда не пересоздаёт несвой LXC и повторно проверяет ARP/IP до выделения ресурса.

## Выполнение CORE (17.11.2026)

- Cloudflare №60 #150: **Success** — отдельный туннель `dh-core` (ID `ef829b9e-c410-4b5b-a754-85ab01b9d31b`) создан без изменения DNS.
- CORE №60 #152: создан и запущен CT1245; первый запуск установщика не завершил E2E по ошибке прав (systemd `200/CHDIR`); никаких стираний или пересоздания.
- CORE №60 #154/#156: диагностика только чтение, выявлена и исправлена причина CHDIR.
- CORE №60 #158/#160: повторная установка; выявлены два пункта контроля — синтаксис ownership assert и ожидание готовности FastAPI сразу после рестарта. Код исправлен с сохранением CT.
- CORE №60 **#162: Success**, `CORE60_DEPLOY=PASS`: PostgreSQL с новой базой, ingestion `127.0.0.1:8080`, dashboard `192.168.11.245:80`, nginx, dashboard API, CF connector `cloudflared-dh-core` — **все пять сервисов active**. Старую базу не копировали.
- Подготовлен отдельный `cutover` с preflight нового соединения, единственной CNAME записью и возвратом старой DNS-записи в случае неуспешной проверки. До успешного cutover старый публичный маршрут действует.

## Состояние после Cloudflare cutover — 17.11.2026

CORE Semaphore №60 Job **#164 — Success**, `changed=0` на PVE:

- Новый tunnel `dh-core` признан Cloudflare `healthy`.
- Установлена единственная ingress route `telemetry.digitalhouses.vip` → `http://127.0.0.1:8080` внутри CT1245, fallback `http_status:404`.
- Единственная существующая Cloudflare DNS CNAME переназначена со старого `a069378e-d11f-479d-90c9-c560460d39e7.cfargotunnel.com` на `ef829b9e-c410-4b5b-a754-85ab01b9d31b.cfargotunnel.com` с проверкой Cloudflare API и публичного HTTP 200.
- Старый Tunnel не удалялся; HOME и старый PostgreSQL не изменены.
- Публичный `GET /healthz` → `200`, `GET /openapi.json` → `DigitalHouses Stats 0.4.1`, `GET /api/summary` → `404` (dashboard недоступен через интернет).
- LAN dashboard `http://192.168.11.245/api/summary` показал **1 настоящую установку и 1 heartbeat** (UTC 2026-11-17T13:09:23), что подтверждает запись нового сервиса в чистую PostgreSQL.
- Дополнительный синтетический POST с `telemetry_policy_version=2`, выполненный вскоре после смены DNS, получил `422`; поэтому полная проверка обеих policy-версий **не подтверждена**. Запрос не записал тестовых данных. Репозиторий продукта допускает v1/v2; возможное влияние момента обновления маршрута не исключено.

Теперь целевое состояние CORE Stats достигнуто без переноса истории. Тестовый DELETE не выполнялся, поскольку тестовый POST завершился 422 и ничего не создал.

### Контрольный аудит после переключения

CORE Semaphore №60 Job **#166 — Success, changed=0**: `dh-core` присутствует,
единственная DNS CNAME `telemetry.digitalhouses.vip` указывает на
`ef829b9e-c410-4b5b-a754-85ab01b9d31b.cfargotunnel.com`; PVE CT1245 и
имя идентифицированы как `OWN_DH_STATS`, LAN IP `.245` занят именно своим
работающим контейнером (`OWN_CT_PRESENT`). Публичная телеметрия `HEALTHY`.

## CORE Stats: full LAN origin and foreign-product audit (17.11.2026)

**Current effective configuration, superseding the historical loopback ingress in Job #164 above:**

```text
Internet dh_ha_apps
  -> HTTPS telemetry.digitalhouses.vip
  -> Cloudflare remote-managed Tunnel dh-core
  -> http://192.168.11.245:8082       (network origin)
  -> nginx access restriction: only CT1245's own IP / loopback
  -> http://127.0.0.1:8080          (Stats ingestion FastAPI)
  -> PostgreSQL inside CORE CT1245

Local LAN dashboard (separate): http://192.168.11.245:80
```

- `#170` CORE Semaphore `origin-network`: **Success**, installed guarded nginx LAN proxy on CT1245. The proxy is reachable by the cloudflared connector running inside the same CT, while other LAN clients receive HTTP **403**. Existing FastAPI remains loopback-only; no service restarted except nginx reload. The local dashboard remains on `:80`.
- `#172` CORE Semaphore `origin-switch`: **Success**, Cloudflare API confirms the single ingress destination **`http://192.168.11.245:8082`**. Only the dedicated `dh-core` Tunnel's ingress was changed; no DNS, HOME, historic data or other product resources were modified. Previous ingress is restored automatically if switching fails its checks.
- Post-change health checks: public `GET /healthz` **200**; public `/api/summary` **404** (dashboard is not public); direct LAN origin `:8082` from DEV **403**; LAN dashboard `/healthz` **200**.
- New CORE provisioning task installs this network-origin proxy too, so future clean deployments use the same architecture.

Read-only `#168` country/product audit used the **most recent heartbeat per installation**, counting product/version/country without returning installation IDs or tokens. At the time of audit, non-KZ:

| Country | Product | Version | Installations |
| --- | --- | --- | ---: |
| NL | `digitalhouses_internet_app` | `0.1.24` | 1 |
| RU | `digitalhouses_internet_app` | `0.1.24` | 1 |
| PL | `digitalhouses_internet_app` | `0.1.24` | 1 |

Four other installations were observed in KZ (two Internet App and two Zigbee Monitor App). `CF-IPCountry` indicates where the request originated; VPN/proxy geolocation may affect it. This is not personal identification.

## Product/agent breakdown within Countries — 17 Nov 2026

- Product source change limited to `DigitalHouses/home-assistant-apps/digitalhouses-stats`, merged in PR [#541](https://github.com/DigitalHouses/home-assistant-apps/pull/541), merge commit `7327e91a`, Stats **v0.4.2**.
- Existing private `/v1/stats/countries` API returns additive `products` entries per country with display names and `observed_installations`, `active_7d`, `active_30d`. Each installation is assigned to its **last** reported country; each country total equals the sum of its product counters. No installation IDs or authentication tokens are returned.
- Countries in the LAN dashboard are expandable/collapsible (keyboard-accessible buttons); their expanded lines share the columns **Known / 7d / 30d** with the country totals. Expanded state survives dashboard Refresh. Static assets have cache-busting URLs.
- CORE task **№60 `update`** updates only the installed DH Stats product/backend/dashboard on CT1245; it does not migrate/delete database contents or touch Cloudflare Tunnel, DNS or other DigitalHouses applications.
- CORE Semaphore Job **#174: SUCCESS** `CORE60_STATS_VERSION=0.4.2`, `CORE60_STATS_COUNTRY_EXPANSION=ENABLED`, country totals E2E PASS. Regression contract tests passed.
- Post-update real read-only API check: six countries, 11 installations/heartbeats. `KZ=6`: Internet App=3, Zigbee Monitor App=2, Recorder App=1. `AU=IL=NL=PL=RU=1`: each Internet App=1. All country group sums match the dashboard summary.
- Public `https://telemetry.digitalhouses.vip/healthz` remained HTTP **200**. Public `/api/countries` remained **404** (countries and dashboard remain LAN-only). PostgreSQL data and Cloudflare origin `192.168.11.245:8082` unchanged.

## Cloudflare Tunnel connector auto-update (17.11.2026)

- Existing `dh-core` connector lives in CORE CT1245 (`192.168.11.245`).
- `cloudflared` was installed from a Debian package; its built-in
  `--autoupdate-freq` flag does not work for package-managed installations.
- HOME and CORE share the same Debian-native auto-update mechanism:
  APT `unattended-upgrades` with existing `apt-daily.timer` and
  `apt-daily-upgrade.timer`; no Semaphore schedule or custom timer.
- CORE №60 action `update-connector` configures the official stable
  Cloudflare APT source and `/etc/apt/apt.conf.d/90-dh-cloudflared-unattended`
  within CT1245. APT policy permits only the `cloudflared` package from
  Cloudflare, disables unattended reboot and dependency removal, and runs
  an upstream `unattended-upgrade --dry-run --debug` check.
- APT post-invoke restarts only `cloudflared-dh-core.service` when the old
  process is still using a deleted executable after package replacement.
  Brief Tunnel reconnection is possible; Stats, PostgreSQL, Tunnel routing,
  Access, DNS and the CT identity are unaffected by this configuration step.
- Old custom CORE `cloudflared-dh-core-update.timer` / updater script were
  removed from the desired configuration. Existing units, if present, are
  disabled and removed at next `update-connector` or new `deploy`.
- CORE Semaphore №00 Job **#176: SUCCESS** refreshed the survey and included
  the `update-connector` action without touching active infrastructure.
- CORE Semaphore №60 Job **#177: SUCCESS** (`update-connector`,
  `failed=0`): CT1245 configured with Debian unattended-upgrades;
  `cloudflared-dh-core.service`, `apt-daily.timer`, and
  `apt-daily-upgrade.timer` active. HOME and other CORE services unchanged.
  Public `https://telemetry.digitalhouses.vip/healthz` returned **HTTP 200**
  after deployment. The next stable cloudflared release has not yet been
  observed applying automatically; that remains subject to upstream release timing.

## CT1245 boot reliability — 25.11.2026

Observed on PVE 8.4.21, Debian 13/systemd 257.13: unprivileged CT1245
had no nesting feature, 18 failed systemd units, AppArmor mount denials
(including sd-mkdcreds ramfs), journald 243/CREDENTIALS, and nginx tried
to bind .245:8082 before ifupdown2 networking.service finished.
The existing network-online.target dependency alone did not prevent this.

- New `deploy` creates CT1245 with `--features nesting=1`, retaining
  unprivileged mode and AppArmor.
- Existing `origin-network` reconciles the same nesting setting and
  native nginx drop-in `/etc/systemd/system/nginx.service.d/10-dh-network.conf`
  (Requires/After=networking.service), preserving existing LXC feature flags.
- If boot parameters change on an existing CT, №60 performs a graceful
  shutdown/start and checks native systemd boot and all Stats services
  before reloading the existing origin. No DB reinstall, DNS changes,
  new timers, boot scripts, or artificial startup delay.
- Public origin remains 192.168.11.245:8082. Nesting increases permitted
  namespace/mount operations; the container remains unprivileged and
  AppArmor is not disabled.
- Live acceptance pending execution on CORE; verify zero failed units,
  nginx and journald active, local/public health 200, and a subsequent
  controlled PVE reboot. Do not mark the incident resolved before testing.
