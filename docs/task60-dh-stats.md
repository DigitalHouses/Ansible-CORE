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
