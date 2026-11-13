# №40 — CORE Infrastructure (`dh-core`)

**Текущая граница задач (12.11.2026):** №40 отвечает только за
подготовку/аудит инфраструктуры центрального PBS (PVE, VM2243,
ZFS/datestore `pbs-core`, базовый маршрут). Рабочая логика PBS Remotes,
Pull Sync, retention, Verify и E2E выделена в **№50 Central Backup**
(`docs/task50-central-backup.md`). Исторические этапы №40 ниже сохранены
без переписывания событий.

**Актуальное состояние (12.11.2026):** `dh-core / Media Server + PBS — VM2243, 192.168.11.243` реально работает. Перенесён из VM2250/.250 без пересоздания ОС и без изменения физического ZFS-диска. Сохранены оба datastore `pbs-serzhan`, `pbs-core`; PVE Storage `pbs-serzhan` перенаправлен на `.243`, а PVE Backup Job исключает VM2243. Ниже сохранены исторические записи исходных аудитов до миграции.

**Этап 1 (история): только аудит, без изменения серверов или хранилищ.**
В Semaphore CORE есть самостоятельная задача `40-Central PBS`.
Её нельзя выполнять через `serzhan-home` HOME Semaphore.

## Фактическая база (аудит 12.11.2026)

- `dh-core / ASRock PVE — 192.168.11.240`: отдельный узел, а не Beelink HOME.
- `dh-core / Ansible + Semaphore — CT1241, 192.168.11.241`: CORE профиль, отдельный каталог.
- `dh-core / Legacy Media Server — VM2250, 192.168.11.250`: PBS 4.2.9,
  datastore `pbs-serzhan` на `serzhan-pool/pbs-serzhan` (занято около 315 ГБ).
  Это работающие копии; **не переиспользовать и не переименовывать** без
  отдельного плана миграции.
- `dh-core / Standard Media Server — VM2243, 192.168.11.243`: пока **не создан**.
- `serzhan-home / Local PBS — VM2223, 192.168.11.223`: TCP 8007 доступен
  напрямую через LAN; CORE и HOME владельца не требуют Cloudflare-маршрута.
- В legacy PBS нет Remote и Sync Job. Рабочая PVE Storage `pbs-serzhan`
  обслуживает существующий старый режим резервирования.

## №40, текущая реализация

Проверяет локальные `site-id=dh-core`, `site-profile=core`, стандарт CORE
PVE `.240`, pinned SSH из bootstrap; читает PVE VM и Storage через pvesh;
проверяет только TCP reachability HOME PBS. Выводит статусы в журнал.
Ничего не создаёт, не удаляет, не запускает копирование, не обновляет
credentials, не меняет ZFS, VM, диски, firewall, Cloudflare или HOME.

## Следующий этап №40: Apply после отдельного решения

1. Утвердить место и размер **отдельного центрального datastore**, не
   смешивая его со старым `pbs-serzhan`. Существующий ZFS пул принадлежит
   legacy VM2250; по S24 целевой CORE Media — VM2243. Нельзя передавать
   один и тот же сырой диск двум работающим VM.
2. Подготовить на HOME ограниченный **читающий все требуемые backup groups**
   PBS identity для CORE. `Datastore.Backup` не даёт читать чужие группы;
   разрешения должны позволять полный Pull, но не удаление источника.
3. Создать на CORE Remote на `serzhan-home`, проверить TLS fingerprint,
   предоставить отдельный datastore namespace для этого HOME и штатный
   PBS Pull Sync Job. `remove-vanished=false` и независимая retention
   policy. Сначала ручной пилот, затем расписание и verify/restore.
4. Добавить остальные HOME по их уникальным подсетям через защищённый
   Cloudflare Private Network. Данные по объектам из S24.

Не включать автоматический перенос документов и HA до появления самих
источников архивов на локальном PBS.

## Живая приёмка этапа 1 (12.11.2026)

CORE Semaphore `dh-core / Ansible — CT1241, 192.168.11.241`:

- №00: Job #2 `success`, каталог пополнился `40-Central PBS`.
- №40: Job #3 `success`, `runner ok=4`, `core40_pve ok=7`,
  `changed=0`, `failed=0`.
- Вывод: `CORE40_SERZHAN_HOME_PBS=REACHABLE`,
  `CORE40_STANDARD_MEDIA_VM2243=ABSENT`,
  `CORE40_LEGACY_MEDIA_VM2250=PRESENT`,
  `CORE40_LEGACY_PBS_SERZHAN=PRESENT`,
  `CORE40_CENTRAL_PBS_STORAGE=NOT_CONFIGURED`,
  `CORE40_PULL_SYNC=NOT_CONFIGURED`.

Аудит принят; **конфигурация приёма копий и восстановление не проверены**,
поскольку не создавались Central datastore, Remote или Sync Job.

## Этап 2: отдельный центральный datastore на существующей VM2250

Решение владельца: не пересоздавать и не перенумеровывать legacy
`dh-core / Media Server + PBS — VM2250, 192.168.11.250`.
В №40 добавлено отдельное действие `prepare`, по умолчанию остаётся
`audit`. `prepare` создаёт только **`serzhan-pool/pbs-core`** как новый
ZFS filesystem и регистрирует PBS datastore **`pbs-core`** на пути
`/serzhan-pool/pbs-core`. Работает из `dh-core / Semaphore — CT1241,
192.168.11.241` через pinned SSH к `dh-core / ASRock PVE,
192.168.11.240` и штатный Proxmox Guest Agent существующей VM2250.

До операции проверяются идентичность VM2250, здоровье пула, datastore
`pbs-serzhan` и отсутствие конфликтов имени, ZFS-объекта, mountpoint
или чужих файлов. При повторном запуске совпадающие конфигурации
сохраняются, чужие — блокируются. Никаких стираний, импорта диска,
переноса ZFS, удаления backup, изменения PVE Storage, PBS Remotes,
Sync Jobs, credentials или prune нет.

**Ограничение:** `pbs-core` и `pbs-serzhan` находятся в одном физическом
пуле `serzhan-pool`, поэтому физически не независимы друг от друга.
Они логически разделены; независимость копий обеспечит source HOME
на другой машине и следующий внешний уровень B2. В `pbs-core`
пока нет собственных Prune/GC/Verify jobs и backup snapshots.

Для первого Pull нужны отдельный source API-токен с `DatastoreReader`
на `serzhan-home / Local PBS, 192.168.11.223`, закреплённый TLS
fingerprint и отдельная настройка CORE Remote и Sync Job. Этот этап
ещё не меняет источник.

## Живая приёмка этапа 2 (12.11.2026)

CORE Semaphore `dh-core / Ansible + Semaphore — CT1241, 192.168.11.241`:

- №00: Job #4 `success`, Survey №40 обновлён: `audit`/`prepare`.
- №40 `prepare`: Job #5 `success`, `core40_pve ok=30 changed=3 failed=0`;
  созданы **только** `serzhan-pool/pbs-core` и PBS datastore `pbs-core`
  внутри `dh-core / Legacy Media/PBS — VM2250, 192.168.11.250`.
- Независимая проверка: PBS видит оба datastore на разных путях;
  ZFS `pbs-core` смонтирован, занято около 24 МБ (служебные метаданные),
  старый `pbs-serzhan` содержит около 315 ГБ и сохранил прежние
  Prune/GC; Remote/Sync Jobs не появились. PBS HTTPS доступен.
- `pbs-core` намеренно **не добавлялся в PVE Storage**; он предназначен
  только как серверная цель PBS Pull Sync, а не локальный backup job PVE.
- Повторный `prepare`, CORE Semaphore Job #6: `success`, `core40_pve ok=25 changed=0 failed=0`, `runner ok=4 changed=0 failed=0`.
  Dataset и datastore не пересозданы — идемпотентность подтверждена.

**Ближайшая зависимость:** на `serzhan-home / Local PBS — VM2223,
192.168.11.223` нужен отдельный токен с `DatastoreReader` и
`DatastoreAudit` для всех нужных backup groups и закреплённый
сертификат. Существующий токен записи `root@pam!pve-local`
**не следует** применять для Pull. После этого №40 сможет создать
CORE Remote, sync в namespace `serzhan-home` без `remove-vanished`,
запустить ручной пилот и отдельно настроить retention/Verify/GC.

## Транспорт для всех HOME (решение владельца, 12.11.2026)

**Этот репозиторий/чат развивает только CORE №40.** Любые задачи HOME,
включая подготовку локального PBS, Cloudflare Tunnel и выдачу credential,
реализуются в соответствующих HOME-чатах. CORE здесь только потребитель
готового HOME-подключения. Никаких HOME-файлов или HOME-заданий из этого
чата не создаём.

Каждый HOME, включая `serzhan-home`, считается удалённым для синхронизации:

- На HOME существующий `cloudflared` устанавливает исходящее соединение
  к Cloudflare. HOME-часть обсуждается и реализуется отдельно.
- На `dh-core / Media/PBS — VM2243, 192.168.11.243`
  клиент Cloudflare One должен направлять трафик к адресу PBS HOME
  через private network route (для PBS достаточно адреса /32).
  CORE №40 отвечает только за клиент, проверку маршрута и Pull Sync.
- `serzhan-home / PBS — VM2223, 192.168.11.223` — первый пилот.
  Из-за общей физической LAN `192.168.11.0/24` маршрут /32 должен
  приоритетно идти через Cloudflare, а не через `eth0`. Это проверяем
  именно из CORE PBS VM, не по IP-ответу из CORE Runner.
- Подключение к PBS использует нативный протокол HTTPS на TCP 8007
  и штатную PBS-аутентификацию. Без дополнительных SSH proxy/forced
  commands, ручного ввода токенов, Access service token headers или
  отдельного публичного прокси для PBS.
- PBS Remote и Pull Sync создаём только после подтверждённого маршрута
  и получения из HOME корректного параметра авторизации по согласованному
  стандартному контракту (его готовит отдельный HOME-чат). Никаких
  `remove-vanished`, автоматических удалений или нового пользовательского
  самописного кода.

В текущей реализации CORE №40 оставлены работающие режимы `audit`
(по умолчанию) и `prepare` (создать отдельный datastore). Прежний,
не запущенный режим `configure` с ручным вводом PBS-токена удалён
из каталога, пока не согласован штатный источник credentials. Старые
данные `pbs-serzhan` и новый `pbs-core` сохраняются без изменений.

Проверка CORE транспорта начнётся с `ip route get 192.168.11.223`
**внутри VM2243**. Отчёт `DIRECT_LAN_NOT_ACCEPTED` — ожидаемое
состояние до подготовки Cloudflare. Он не означает отказ PBS.

## Приёмка исправления границ проекта (12.11.2026)

- CORE №00 Job #8 `success`; Survey №40 оставляет только `audit` и `prepare`.
- CORE №40 Job #9 `success`: `runner ok=2 changed=0 failed=0`,
  `core40_pve ok=10 changed=0 failed=0`.
- `CORE40_SOURCE_ROUTE=DIRECT_LAN_NOT_ACCEPTED` подтверждён из реальной
  CORE PBS VM2250. Ранее проверенная локальная TCP-доступность HOME
  **не считается проверкой Cloudflare**.
- За пределами CORE не было изменений: HOME-задачи и credential-токены
  не создавались, PBS Remote/Sync Jobs не активированы.

## Живая приёмка перенумерации CORE Media/PBS (12.11.2026)

- На `dh-core / ASRock PVE — 192.168.11.240` старую VM2250
  корректно выключили. Без `qm destroy` и переустановки.
- Переименованы только два LVM-Thin тома `pve/vm-2250-disk-0` →
  `pve/vm-2243-disk-0` и `pve/vm-2250-cloudinit` →
  `pve/vm-2243-cloudinit`, а также конфигурация VMID.
- `dh-core / Media Server + PBS — VM2243, 192.168.11.243`
  запущена с прежними MAC, PCI passthrough GPU и SATA-контроллера.
  Гостевой Linux hostname и имя Proxmox VM пока **сохранены** как
  `mediaserver-serzhan`; отдельное переименование не требовалось.
- Гостевая сеть Netplan и Cloud-Init используют `.243`. Портал,
  rclone GUI и PBS отвечают HTTP 200. ZFS `serzhan-pool` ONLINE.
- PVE Storage `pbs-serzhan` active; прежний токен и сертификат PBS
  не менялись. PVE Backup Job `dh-local-pbs-serzhan` исключает VM2243.
- Существующие datastore `pbs-serzhan` и `pbs-core` доступны по
  исходным путям. PBS Remote/Sync Jobs пока не настроены.
- Резервные копии исходных файлов PVE: `/var/lib/digitalhouses/
  core-media-2243-migration-20261112/`. Копии изменённых файлов
  гостя: `/root/dh-core-2243-migration/`.
- Существующий локальный сертификат `media-account-pki/server.crt`
  проверен: SAN по-прежнему содержит **192.168.11.250**. Он не
  перевыпускался в рамках смены VMID/IP; при обращении к сервису,
  использующему этот сертификат, по IP `.243` TLS-проверка имени
  может не пройти. Это отдельно от штатного PBS TLS (PBS/PVE работает).

## Приёмка CORE №40 после переноса VM2243 (12.11.2026)

- CORE Semaphore Job #10 (`audit`): `success`, `core40_pve ok=10 changed=0 failed=0`, `runner ok=2 changed=0 failed=0`. Показано `CORE40_STANDARD_MEDIA_VM2243=PRESENT`, `CORE40_LEGACY_MEDIA_VM2250=ABSENT` и правильный `CORE40_TARGET_GUEST=dh-core/VM2243/192.168.11.243`.
- CORE Semaphore Job #11 (`prepare`): `success`, `core40_pve ok=28 changed=0 failed=0`, `runner ok=2 changed=0 failed=0`; оба datastore и mountpoint ZFS приняты без повторного создания.
- Cloudflare на CORE/HOME **не меняли**. Следующий этап туннелей выполняется в профильном чате, по отдельному решению пользователя.

## Повторный аудит транспорта CORE → HOME (12.11.2026)

На `dh-core / Media Server + PBS — VM2243, 192.168.11.243`
через Proxmox Guest Agent проверено:

- Debian 13 (trixie), x86_64;
- `cloudflare-warp` не установлен, `warp-svc` неактивен;
- `ip route get 192.168.11.223` идёт через `eth0` (напрямую
  через общую LAN), поэтому защищённый маршрут **не подтверждён**;
- в `dh-core / Semaphore — CT1241, 192.168.11.241` environment
  пока `Empty`; Cloudflare Service Token для headless enrollment
  отсутствует в CORE credentials;
- никакие HOME ресурсы, Cloudflare policies, сетевые маршруты и PBS
  сервисы не менялись.

В №40 (`audit`) добавлен **только** read-only контроль наличия
Cloudflare One Client, статуса `warp-svc` и маршрута к пилотному HOME
PBS. Подготовка ZFS `prepare` осталась прежней.

### Зависимости для развертывания транспорта

1. HOME №70 — на существующем cloudflared PVE сайта `serzhan-home`
   опубликовать **private route 192.168.11.223/32** к HOME PBS,
   не меняя его опубликованные приложения и не запуская CORE задачи.
2. CORE: создать штатный Cloudflare Zero Trust Service Token для
   автоматической регистрации headless клиента и политику
   `Service Auth` для enrollment; сохранить `organization`,
   `auth_client_id` и `auth_client_secret` вне Git, в
   существующем Semaphore.
3. CORE: установить штатный Cloudflare One Client непосредственно в
   VM2243; разрешить только PBS HOME IP `192.168.11.223/32` через
   Split Tunnels, не перехватывать весь трафик VM.
4. Проверить на VM2243 статус клиента, маршрут через Cloudflare и
   **реальную** HTTPS-доступность HOME PBS TCP 8007. В общей
   LAN случайный успешный TCP по `eth0` не считается успешным тестом.
5. После приёмки Cloudflare-транспорта переходить в №50 к штатному
   read-only PBS API identity и Pull Sync.

Документация Cloudflare по headless enrollment:
https://developers.cloudflare.com/cloudflare-one/tutorials/deploy-client-headless-linux/

Документация Split Tunnels:
https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/configure/route-traffic/split-tunnels/

### Живая приёмка расширенного аудита №40

- CORE Semaphore №40 Job #19: `success`, commit `e93e493`.
- `core40_pve ok=12 changed=0 failed=0`;
  `runner ok=2 changed=0 failed=0`.
- `CORE40_SOURCE_ROUTE=DIRECT_LAN_NOT_ACCEPTED`.
- `CORE40_CLOUDFLARE_CLIENT=NOT_INSTALLED`.
- `CORE40_CLOUDFLARE_SERVICE=INACTIVE`.
- PBS и HOME не изменялись. Это приёмка **аудита**, а не
  Cloudflare-транспорта или Pull Sync.

### CORE40 Cloudflare One Client — пилот 12.11.2026

В задачу №40 добавлены два отдельных действия:

- `cf-audit` — проверка CF API, Access enrollment app, service token,
  private route и состояния клиента без изменений;
- `cf-install` — штатная установка пакета `cloudflare-warp` в
  `dh-core / Media Server + PBS — VM2243, 192.168.11.243`, без
  сохранения enrollment credentials и без маршрутизации через WARP.

Факты из запущенных jobs:

- №00 Job #26: `success`, каталог добавил `cf-audit`.
- №40 Job #27: `error`, исправлено чтение team name из
  Semaphore `env`, а не Ansible var. №05 не менялась.
- №40 Job #29 (`cf-audit`): `success`, `changed=0`;
  Cloudflare routes/apps/policies/service_tokens API доступны (HTTP 200),
  Device Profiles и default Split Tunnel API возвращают HTTP 403;
  private route `192.168.11.223/32` не подтверждён, Service Token
  `dh-core-pbs` не подтверждён по возвращённому API набору.
  Cloudflare WARP еще не был установлен.
- №00 Job #30: `success`, добавил `cf-install` в Survey №40.
- №40 Job #31 (`cf-install`): официальный Cloudflare apt key и
  Debian `trixie` repository настроены, пакет установлен; Semaphore
  ошибочно пометил job как `error`, поскольку `qm guest exec`
  превысил default 30s и вернул PID без `exitcode`. Исправлено
  `--timeout 300` для apt-команд.
- №40 Job #32 (`cf-install`): `success`, `changed=0 failed=0`;
  повторный прогон **идемпотентен**.
- Фактическая проверка в VM2243: `cloudflare-warp 2026.8.2115.0`,
  `warp-svc=active`, `proxmox-backup-proxy=active`; маршруты к
  `192.168.11.223` и `1.1.1.1` по-прежнему через `eth0`.
- `warp-cli status` пока запрашивает принятие Terms of Service.
  Устройство не регистрировалось, `mdm.xml` не создавался,
  DNS/Split Tunnels/Cloudflare account не изменялись.

**Следующий этап:** сначала подтвердить Service Auth device enrollment
policy, private route HOME №70 и Include `192.168.11.223/32`
в применимом CORE device profile (сейчас API scope 403); затем
аккуратно регистрировать WARP в этой VM с использованием
№05 credentials и проверкой маршрута, PBS/Media доступности.
Прямой LAN путь не считать успешным CF E2E.

Источники:
- https://developers.cloudflare.com/cloudflare-one/tutorials/deploy-client-headless-linux/
- https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/deployment/device-enrollment/
- https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/configure/route-traffic/split-tunnels/
- https://github.com/proxmox/pve-docs/blob/master/generated/qm.1-synopsis.adoc

### CORE40 headless registration — implementation (12.11.2026)

Added explicit `cf-register` option to existing task №40, not a new task
or credentials store. Registration runs **only** if the operator
selects `DH_CORE40_ACTION=cf-register` **and**
`DH_CORE40_CF_ACCEPT_TOS=yes` in Semaphore Survey. Default is `no`.
The task invokes `warp-cli --accept-tos` only after that consent.

- Uses `DH_CLOUDFLARE_TEAM_NAME`, enrollment Client ID and Client Secret
  from existing Semaphore №05 native Variable Group (no repeated input).
- Creates official `/var/lib/cloudflare-warp/mdm.xml` through QEMU guest
  agent's `--pass-stdin 1`, without a secret in process arguments,
  PVE temporary files, Git or logs. File permissions: root-only `0600`.
- First registration sets `service_mode=postureonly`,
  `auto_connect=0`, `onboarding=false`. Cloudflare documents that
  Posture only mode routes neither IP traffic nor DNS. This is a
  **registration stage only**, not HOME private network connectivity.
- Existing MDM file is **not overwritten**: repeat run verifies its SHA256
  against current №05 values. Token rotation/re-enrollment requires a
  separate explicitly controlled change.
- Restarts `warp-svc` only on first creation, verifies organization
  registration with `warp-cli registration show`, then checks status,
  unchanged `eth0` routes and active PBS proxy. Raw credential material,
  MDM content and raw Warp registration information are all `no_log`.
- An unsuccessful registration must not be described as successful.
  The protected `mdm.xml` can remain on disk for a retry once the
  Service Auth enrollment policy is configured.
- A separate future action to carry **HOME PBS traffic** via WARP must
  validate HOME №70 route and a safe CORE-only `Include` Split Tunnel
  profile before using `service_mode=warp`; it is deliberately not
  part of `cf-register`.

Official references:
- https://developers.cloudflare.com/cloudflare-one/tutorials/deploy-client-headless-linux/
- https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/deployment/mdm-deployment/parameters/
- https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/configure/modes/

### CORE40 preflight extension after live Cloudflare read (Job #35)

Read-only `cf-audit` Job #35: `success`, `changed=0 failed=0`.
The Cloudflare account associated with the canonical
`digitalhouses.vip` zone exposes a WARP enrollment application but its
API returned **0 service tokens**, **0 Service Auth policies**, and
**0 private network routes**. Device Profiles / Split Tunnel endpoints
returned `403`. This result conflicts with the token created in the
dashboard, so check whether that token was created under another
Cloudflare account or whether the API token uses a different account.

Registration now includes a **read-only API preflight on CORE Runner**:
the `dh-core-pbs` service token and at least one Service Auth
(`decision=non_identity`) policy must be visible in that canonical
account. Failure blocks before any command on PBS VM2243, including
writing `mdm.xml` or accepting ToS. Attachment of the policy to
Device enrollment permissions still needs to be confirmed in Cloudflare
Dashboard. The private route and Device Profiles are not required
for initial posture-only enrollment, but are mandatory before
traffic tunneling.

### Validation after user saved Device enrollment permissions (12.11.2026)

CORE №40 `cf-audit` Job #36 confirmed that the new Service Auth policy
is visible. Enhanced read-only Job #37 confirmed:

- WARP device enrollment application exists (exactly one).
- Reusable policy `dh-core-pbs-enrollment` exists (exactly one) with
  `decision=non_identity` and exactly one Service Token include rule.
- The expected Service Auth policy **is attached** to WARP enrollment
  application (`GET .../access/apps/{id}/policies`: HTTP 200).
- Direct GET for its referenced Service Token returns HTTP **403**:
  current CORE API token does not have `Access: Service Tokens Read`.
  The Service Token list returns 0 under the same read restriction.
  This does **not** show the token is absent; it exists in the user's
  Cloudflare dashboard, where its state is Enabled.
- Private route to HOME PBS is a *separate* uncompleted HOME #70 requirement.

Updated CORE №40 `cf-register` preflight to require an exact Service Auth
policy name, `non_identity` decision, exactly one `service_token` rule,
and attachment to WARP enrollment. An HTTP 403 from read-only token
metadata is acceptable; on HTTP 200, it also verifies its name and
Client ID against Semaphore №05. No ToS acceptance or registration has
been performed: the operator must explicitly select `cf-register` and
`DH_CORE40_CF_ACCEPT_TOS=yes` via Semaphore Survey.

### CORE40 registration — executed 12.11.2026, Job #39

- Operator requested ChatGPT to run №40; Semaphore Survey submitted
  `DH_CORE40_ACTION=cf-register`, `DH_CORE40_CF_ACCEPT_TOS=yes`.
- Semaphore Job #39 completed `success` on commit `6147ea2`:
  runner `ok=15 changed=0 failed=0`;
  core40_pve `ok=38 changed=2 failed=0`.
- Cloudflare read-only Service Auth preflight passed and policy is
  attached to WARP enrollment. Stored №05 credentials were used.
- MDM streamed securely to VM2243, `mdm.xml` permissions `0600`.
  `warp-cli --accept-tos registration show` confirmed organization
  registration on the guest.
- After registration `proxmox-backup-proxy=active`.
  `ip -4 route get 192.168.11.223` still uses `eth0`
  (`192.168.11.243`), no WARP traffic route was enabled.
- Direct `warp-cli --accept-tos status` after Job #39:
  `Disconnected / Manual Disconnection`. This is consistent with
  `auto_connect=0`; **registered is not the same as connected**.
- Next: HOME #70 tunnel private route and isolated CORE Include
  Split Tunnel profile; then only enable WARP traffic forwarding
  in a separate guarded phase. Backup/PBS sync remains task #50.

### CORE40 posture-only connection test — 12.11.2026

A temporary `cf-posture-connect` pilot was launched as Semaphore
Job #41 after Job #40 updated the catalog. The WARP client remained
registered, but the connection returned
`Status update: Unable; Reason: Failed to set mTLS Identity`
(`CF_FAILED_TO_SET_MTLS`). Job #41 correctly returned `error`;
no Cloudflare private-network tunnel was established.
Cloudflare documents this as an inability to provision a valid
client certificate **specific to Posture only mode**.
The client was explicitly disconnected again using
`warp-cli --accept-tos disconnect`; independent checks confirm:
`Disconnected / Manual Disconnection`,
PBS proxy `active`, route to HOME `192.168.11.223` still via `eth0`.

Rather than enable unrelated mTLS certificate provisioning just
to run a posture-only test, we removed the optional
`cf-posture-connect` action. The already-successful
`cf-register` device enrollment remains intact. For our real
private-network objective the next necessary steps are **HOME #70**
Cloudflare private route and a **CORE-specific Include device
profile**, after which CORE #40 can safely enable traffic mode.
The temporary failure was not a HOME or PBS backup failure.

Cloudflare reference:
https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/troubleshooting/client-errors/

### CORE safe acceptance and remaining gate (12.11.2026)

- After recovery from optional posture-only connection test:
  CORE №00 Job #42 `success`, removed the experimental action;
  working Cloudflare registration and MDM remained unchanged.
- CORE №40 `prepare` Job #43 `success`, `changed=0 failed=0`;
  verified healthy `serzhan-pool`, exact ZFS dataset mountpoint,
  `atime=on`, correct `pbs-core` datastore and untouched `pbs-serzhan`.
  No creation, deletion, migration or Sync Job was needed.
- CORE №50 read-only audit Job #44 `success`, `changed=0 failed=0`.
  `CORE50_REMOTE_COUNT=0`, `CORE50_PULL_SYNC_JOB_COUNT=0`,
  `CORE50_BACKUP_E2E=NOT_RUN`. No source backups have been pulled.
- CORE №40 `cf-audit` Job #45 `success`, `changed=0 failed=0`.
  Service Auth policy `READY`, but Cloudflare private route
  `192.168.11.223/32` `NOT_CONFIRMED` / no route in account.
  Device profile and Split Tunnel API still `403`. Direct LAN
  `dev eth0` remains and is **not** accepted as Cloudflare E2E.

**External prerequisites before any WARP traffic-mode change:**

1. HOME №70 must expose **only** `192.168.11.223/32` using the
   existing HOME PVE cloudflared tunnel. It owns the HOME route;
   do not change HOME from this CORE task.
2. CORE must gain a dedicated Cloudflare device profile with
   Split Tunnels **Include** and the remote HOME PBS /32 route,
   applied only to CORE PBS device. Do not change the shared
   default/other homes' profiles. The existing CORE №05 CF API
   token has insufficient rights (`GET devices/policies: 403`).
   Official device-profile API requires account permission
   **`Zero Trust Write`**. Enter a suitably scoped replacement
   API token through existing CORE Semaphore №05 (no new secret
   store, no plaintext in DEV/repo).
3. Then add guarded CORE №40 traffic-mode activation with checks
   for exact HOME route, effective Include profile and safe
   management interface, plus network/PBS rollback on failure.
   Only after end-to-end Cloudflare route is proven can CORE
   №50 configure PBS Remote, Pull Sync, retention, Verify and
   a real restore test.

No custom Python was added; this is still native Ansible only.

### CORE40 device profile after API permission update (12.11.2026)

User edited existing Cloudflare `Ansible token` and added account
`Zero Trust: Edit` while preserving previous permissions.
CORE Semaphore №40 `cf-audit` Job #46 `success changed=0 failed=0`:
GET Device Profiles and Split Tunnels changed from 403 to **200 OK**;
Service Auth enrollment policy still READY.

CORE №00 Job #47 updated the catalog. Added independent
`cf-profile-prepare` action to №40, without changing task №05 or
the shared Semaphore Variable Group.

CORE №40 Job #48 (audit-safe attempt) failed **before modifications**
due to an unnamed Cloudflare default-policy record. Fixed the Ansible
filter to ignore unnamed entries; no custom Python added.

CORE №40 Job #49 **success**, `changed=1 failed=0`: created dedicated
Cloudflare WARP Device Profile `dh-core-pbs-private`:

- `enabled=false` — **inactive**, cannot affect other devices yet;
- `match=identity.service_token_uuid == "<UUID of dh-core-pbs token>"`,
  derived from the existing `dh-core-pbs-enrollment` policy;
- Split Tunnels mode **Include**, only `192.168.11.223/32`;
- no alteration of shared Default profile, routes or DNS;
- all Cloudflare API credentials remain in existing Semaphore №05.

CORE №40 Job #50 repeated the same action successfully
`changed=0 failed=0` (idempotence and API readback confirmed).
Direct guest verification after this action: WARP
`Disconnected / Manual Disconnection`,
`proxmox-backup-proxy=active`,
route to HOME PBS still `eth0` from `192.168.11.243`.

**The remaining external dependency** is the HOME №70 private route
`192.168.11.223/32` through HOME PVE cloudflared. The last CORE
Cloudflare audit returned 0 private routes for the account.
Do not enable the new profile or switch WARP traffic mode before the
HOME route is independently verified and the physical CORE management
path plus rollback are checked. CORE №50 remains downstream.

Official Cloudflare reference:
https://developers.cloudflare.com/api/resources/zero_trust/subresources/devices/subresources/policies/subresources/custom/methods/create/

### CORE40: HOME route confirmed and real Cloudflare E2E accepted (13.11.2026)

HOME №70 delivered route `192.168.11.223/32` through existing
`serzhan-home` tunnel:
- Tunnel UUID `6a04d9cd-0b17-48f3-8366-9f86ea08cb24`;
- Private Route ID `eebd7ec3-e1dd-46eb-95e7-9f6a85f16905`;
- HOME PVE `192.168.11.220`, HOME PBS `192.168.11.223:8007`
  (VM2223).

CORE №40 `cf-audit` Job #51 **success**:
`CORE40_CF_HOME_PRIVATE_ROUTE=PRESENT`.
CORE №00 Job #52 installed `cf-transport-audit`.
CORE №40 Job #53 **success changed=0**:
verified exact route ID, tunnel UUID and Cloudflare account;
the dedicated `dh-core-pbs-private` device profile matched only
the `dh-core-pbs` service token, enabled=false, Include only
`192.168.11.223/32`; guest was still posture-only/disconnected.

Added CORE №40 `cf-transport-enable` with strict preflight,
traffic-only MDM, direct-PVE/QEMU Guest Agent rollback, and
required evidence **Connected + CloudflareWARP route + HTTPS 200**.
DNS, management/default routes and PBS proxy are independently checked.
No HOME, new tunnel, other device profiles or backup jobs touched.

- Job #55: Cloudflare PATCH with additional `service_mode_v2`
  rejected HTTP 400. Automatic rollback restored original
  `postureonly` MDM, disconnected WARP and disabled the
  dedicated profile; PBS proxy remained active.
- Job #56: PATCH only `enabled=true` succeeded. The guest's
  official MDM `service_mode=tunnelonly` independently enforces
  **Traffic only** without DNS interception. Guest policy confirmed
  `Profile ID` matches `dh-core-pbs-private` and
  `Include 192.168.11.223/32` before connect.
  **Success**, `runner changed=4 failed=0`.
  `warp-cli status` returned `Connected / Network: healthy`.
  `ip -4 route get 192.168.11.223`:
  `dev CloudflareWARP table 65743 src 100.96.0.6`,
  **not eth0**, despite CORE and HOME sharing physical
  `192.168.11.0/24`.
  Real HTTPS origin `https://192.168.11.223:8007/`
  returned **HTTP 200**. DNS hash, CORE PVE route, Internet
  route and PBS proxy unchanged.

Then enabled persistent MDM `auto_connect=1` **only on CORE PBS**
(no VM reboot). CORE №00 Job #57 added `cf-transport-persist`.
CORE №40 Job #58 **success, changed=2 failed=0**:
restarted only `warp-svc`; client reconnected automatically,
HOME route remained `CloudflareWARP`,
HTTPS `:8007` again returned 200, PBS active, DNS unchanged.
Independently reconfirmed `Connected / Network: healthy` and
source WARP IPv4 `100.96.0.6`.

CORE №40 Job #59 `cf-transport-audit`: **success changed=0**,
`ACTIVE`, `TRAFFIC_ONLY_CONNECTED`,
`HTTPS_200_VIA_WARP`. Read-only audit now supports both
prepared and active states.
CORE №40 Job #60 repeated `cf-transport-enable`:
**success changed=0** (does not reactivate working transport).
CORE №40 Job #61 repeated `cf-transport-persist`:
**success changed=0** (persistent configuration idempotent).

**№40 Cloudflare private-network transport acceptance: PASSED.**
No full VM reboot was performed; service-restart persistence was tested.
Now move to **CORE №50** (HOME PBS readonly credentials, Remote,
Pull Sync, retention, Verify, actual restore). Never count direct
LAN success as Cloudflare proof. Do not modify HOME from CORE.

## Историческое завершение WARP и переход на Tailscale (13.11.2026)

Секции выше документируют **исторически выполненные тесты**.
Они не описывают текущую целевую архитектуру.

- В CORE PBS VM2243 вместо WARP используется Tailscale
  `dh-core-pbs` / `100.97.126.67`.
- Пакет Cloudflare WARP удалён и конфигурационные остатки очищены.
- У CORE №40 **нет** действий `cf-audit`, `cf-install`,
  `cf-register`, `cf-profile-prepare`, `cf-transport-audit`,
  `cf-transport-enable`, `cf-transport-persist`.
  Доступны только `audit` и `prepare`.
- Все сетевые операции перенесены в **CORE №71**;
  Cloudflare Tunnel/Access для веб-приложений не затрагивались.
- Полный журнал приёмки: `docs/task71-tailscale.md`.

## Контроль после вывода WARP (13.11.2026)

- CORE №00 Job #76 — `success`: актуальный Survey №40
  `audit`/`prepare`, секреты и прежние Task history сохранены.
- CORE №40 Job **#77** — `success changed=0 failed=0`.
  VM2243 и legacy storage остались; сетевое управление
  передано CORE №71. WARP playbook actions больше не существуют.
