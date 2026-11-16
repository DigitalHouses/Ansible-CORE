# №60 — CORE DH Stats: диагностика и план переноса

**Текущий этап: только `audit`.** Никаких LXC, DNS, Cloudflare Tunnel, HOME или PostgreSQL данных не изменяем. Режим `apply` не реализован и не предлагается до сверки текущей базы и Tunnel.

## Подтверждённый исходный контракт

- Продукт: `DigitalHouses/home-assistant-apps/digitalhouses-stats`.
- Исходный сервер по старой документации: HOME CT7000 `digitalhouses-stats`, IP `192.168.11.254` **исторический**, на 16.11.2026 актуальный IP CT7000 не подтверждён. Адрес `.254` теперь занимает DEV CT1254, поэтому нельзя копировать старую IP-конфигурацию в CORE.
- Public HTTPS: `https://telemetry.digitalhouses.vip`; `GET /healthz` возвращает `200 {"status":"ok"}` при проверке из DEV 16.11.2026.
- Приём: FastAPI/systemd `127.0.0.1:8080`, `POST /v1/heartbeat`, `DELETE /v1/installation`, доверенный Cloudflare `CF-IPCountry`.
- Dashboard: **только LAN**, nginx `:80` + отдельная FastAPI `127.0.0.1:8081`. В исходном скрипте и nginx hardcoded `192.168.11.254`, требуется параметризация.
- Хранилище: PostgreSQL в том же LXC (`digitalhouses_stats`, `installations` и append-only `heartbeats`), миграция должна сохранять installation IDs, token hashes, timestamps и историю.
- Cloudflare origin и конкретный Tunnel сейчас **не подтверждены из Cloudflare API**. Публичное здоровье доказывает доступность сервиса, но не путь до CT7000.

## Кандидат CORE

- PVE `192.168.11.240`, CT **1245**; IP **192.168.11.245/24**; PVE имя **`dh-stats-CORE`** (строгий суффикс `-CORE`). Это кандидат, занятость проверяет №60 audit. IP-конфликт вне Proxmox требует отдельной проверки перед созданием.
- Debian LXC, один сервис с локальным PostgreSQL, без зависимости от HOME/VM2243 и без отдельной Stats-базы на CT1244. Начальные ресурсы по проекту: 1 vCPU, 1 ГиБ RAM, 16 ГиБ SSD — уточнить по фактическому размеру текущей БД перед `apply`.
- **Тот же** публичный домен `telemetry.digitalhouses.vip`; никаких изменений в коде клиентов `dh_ha_apps`.
- Cloudflared/Tunnel cutover должен сохранить защиту: приложение принимает `CF-IPCountry` только от доверенного Cloudflare ingress, прямой интернет-доступ до `:8080` не допускается. Локальный dashboard не должен публиковаться через публичный путь.
- Существующий CORE nightly PVE backup job `dh-core-pbs-daily` захватывает новый CT по `all=1` (исключение VM2243), но до завершения переноса нужен отдельный PostgreSQL dump/restore с проверкой.

## Минимальный последующий план (не выполнялся)

1. Прочитать реальный `pct config 7000`, конфигурацию сервисов и Cloudflare Tunnel; зафиксировать БД (размер, схемы, количество installations/heartbeats), backup и свободное место. HOME только read-only до разрешённого переключения.
2. Доказать отсутствие коллизии `.245` в CORE LAN, развернуть **новый** CT1245 и приватно проверить ingestion/dashboard без публикации. Обновить IP в nginx/install-local-dashboard.
3. В согласованное окно остановить запись в старую БД, сделать финальный `pg_dump`, восстановить на CORE; проверить счётчики, схему и версию, без сброса installation IDs.
4. Перевести существующий публичный Tunnel/hostname на CORE **без одновременной записи в две базы**, проверить публичный health и приём одного штатного heartbeat. Сохранить возможность отката до первой записи CORE, не оставлять два активных ingest origin.
5. Только после приёмки отключить старый ingest и запустить штатный backup CT1245.

## Текущая задача

CORE Semaphore **№60** (`playbooks/core-stats.yml`), режим **`audit`**: только получение списка PVE guests и имени, проверка CORE адресации и текущего публичного `/healthz`. Печатает `CORE60_*`. Не изменяет ни один PVE/LXC, DNS, БД или Tunnel; не делает и не эмулирует deployment.
