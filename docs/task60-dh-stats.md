# №60 — CORE DH Stats: действующая эксплуатация

Два действия Semaphore (после синхронизации каталога задачей №00):

- **Создать** (`create`): если CT1245 отсутствует, создать непривилегированный Debian 13 LXC с nesting=1, установить DH Stats, PostgreSQL, LAN dashboard, защищённый origin и cloudflared с родным Debian unattended-upgrades. Создать или переиспользовать выделенный Tunnel dh-core и принадлежащую ему запись telemetry.digitalhouses.vip после локальной готовности. Чужие записи DNS не перехватывать. Если управляемый CT уже существует, не изменять его.
- **Обновить** (`update`): обновить существующую установку DH Stats и dashboard, привести параметры загрузки и локального origin к текущей конфигурации. Не пересоздавать CT, не удалять данные PostgreSQL, не менять DNS/Tunnel. При необходимости штатный graceful shutdown/start только CT1245 для применения nesting и проверки запуска nginx.

Проверки выполняются внутри выбранного действия. Нет отдельных действий диагностики, пересоздания, миграции, настройки Tunnel и origin. HOME не затрагивается.

## Адреса и архитектура

- dh-core / PVE: 192.168.11.240; Semaphore CT1241: 192.168.11.241.
- dh-core / DH Stats: CT1245 dh-stats-CORE, 192.168.11.245.
- LAN dashboard http://192.168.11.245:80, dashboard API 127.0.0.1:8081.
- Public telemetry https://telemetry.digitalhouses.vip → dh-core Tunnel → http://192.168.11.245:8082 → nginx (только локальный connector) → ingestion 127.0.0.1:8080 → локальный PostgreSQL.
- Исходники продукта DigitalHouses/home-assistant-apps/digitalhouses-stats. Изменения продукта не входят в Ansible-CORE.

## Исправление загрузки 25.11.2026

PVE 8.4.21, Debian 13/systemd 257.13: без nesting выявлены 18 failed units, AppArmor mount denials, journald 243/CREDENTIALS; nginx попытался привязать статический IP до завершения ifupdown2 networking.service. Новый CT создаётся с nesting=1; существующий обновляется через «Обновить». Штатный drop-in nginx Requires/After=networking.service. При изменении параметров загрузки выполняется контролируемый restart CT с проверкой systemd и сервисов. Unprivileged и AppArmor сохранены; nesting расширяет разрешённые namespace/mount операции. Без таймеров и искусственных задержек.

Приёмка исправления на живом CT и после перезагрузки PVE пока не подтверждена. История миграции и прежних действий сохранена в Git.
