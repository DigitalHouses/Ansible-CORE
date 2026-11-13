# №50 — Central Backup

**Актуальная архитектура:** [Central Backup HOME Push → CORE](architecture-central-backup.md).
Решение принято 13.11.2026. **Ранее запланированная CORE Pull Sync
заменена на HOME Push Sync.** Старые аудиты отражают историческое
состояние; они не являются техническим заданием на настройку Pull.

## Назначение и границы

Центральный PBS — CORE VM2243, `192.168.11.243:8007`, datastore
`pbs-core`. Для каждого зарегистрированного HOME в одном datastore
предусмотрен **собственный namespace** `<home-id>` (например,
`serzhan-home`), а не отдельный datastore на дом.

- **HOME:** автономно создаёт локальные PVE/PBS резервные копии,
  на своём PBS настраивает Remote **на CORE** и штатный
  `sync-direction=push`; запускает Push Sync по согласованному
  расписанию либо вручную при тестировании.
- **CORE №50:** управляет **полученными в центре** копиями:
  namespace-scoped retention/Prune/Verify, datastore-wide GC,
  мониторинг свежести backups по каждому HOME, проверенный Restore.
- **CORE №10 (проект):** единая регистрация HOME в центральной
  системе; пока не реализована.
- **CORE №40:** CORE инфраструктура и уже принятый исходящий
  Cloudflare маршрут CORE → HOME. Он не заменяет проверку
  обратного направления HOME → CORE.
- **B2:** отложено; не входит в реализацию №50.
- Legacy datastore `pbs-serzhan` на CORE и действующие HOME backup
  jobs не менять.

Равные полномочия HOME означают **одинаковую роль для отправки
резервных копий**, но отдельный namespace каждого дома.
Токены для HOME → CORE создаются на **CORE PBS**, а не на HOME PBS
для входящего CORE Pull. Credentials не хранить в Git или Survey.

## Текущая реализация — только аудит

`playbooks/core-backup.yml` выполняет безопасный аудит через
Semaphore CORE CT1241, проверяет VM2243, datastore `pbs-core`
и отсутствие неожиданных legacy Remote/Pull Job. Имеющиеся проверки
`remote list` и `sync-job list` **не конфигурируют Pull**.
Отсутствие CORE Pull Jobs — штатное целевое состояние в Push-модели.

Шаблон Semaphore №50 (ID 3) остаётся тем же: история сохраняется,
новых фиктивных пунктов Survey не добавляется. Не запускать
синхронизацию, удаление, изменение ZFS, credentials или namespaces
в рамках текущего аудита.

**Последний известный аудит:** Job #62 (13.11.2026):
`success, changed=0, failed=0`; CORE `pbs-core` и legacy
`pbs-serzhan` присутствуют; `remote=0`, `pull_sync=0`,
backup E2E ещё **не запускался**.

## Следующий этап — по утверждённой модели

1. Проверить реальный приватный транспорт **HOME → CORE PBS
   192.168.11.243:8007**, не путать его с принятым маршрутом
   CORE → HOME или прямым LAN при пересекающихся подсетях.
2. Спроектировать и реализовать регистрацию `home-id` в CORE
   (№10), namespace `pbs-core/<home-id>` и выдачу штатного
   центрального PBS токена HOME с единым для всех домов набором прав.
3. **В Ansible-HOME** создать PBS Remote на CORE и Push Sync
   с целью `pbs-core/<home-id>`, `remove-vanished=false`.
   Source datastore/namespace выбирать по реальному HOME-аудиту.
4. На пилоте `serzhan-home` принять и проверить реальные snapshots,
   повторный Push, центральный Verify и тестовое восстановление.
   При сбое CORE локальные HOME Backup Jobs продолжают выполняться.
5. После пилота — согласовать центральные namespace-scoped
   retention/Prune, datastore GC, мониторинг и расписания
   Push Sync на HOME. Подключать другие HOME по той же модели.

**Критерий E2E:** реальные snapshots соответствующего HOME видны
в назначенном namespace `pbs-core`; повторный Push не разрушает
историю; успешные Verify и **реальное тестовое восстановление**.
Статус задачи `success` без данных не считается приёмкой.

## Исторические факты — не актуальная Pull-архитектура

- 12.11.2026: CORE Semaphore шаблон №40 переименован с сохранением
  ID 2, репозитория, credentials и истории. №00 Job #15 создал
  №50 как новый шаблон ID 3. №50 Job #16:
  `runner ok=2 changed=0 failed=0`,
  `core50_pve ok=9 changed=0 failed=0`.
  CORE VM2243 содержит `pbs-core` и `pbs-serzhan`.
  CORE `Remote=0`, `Pull Sync=0`.
  №40 Job #17 `audit` успешен, №00 Job #18 не создал дублей.
- До 13.11.2026 рассматривалась другая схема:
  центральный PBS Pull из HOME с read-only HOME PBS token.
  **Отказались от неё. HOME больше не требуется создавать токен
  для CORE Pull.**
- 13.11.2026: HOME №70 опубликовал private route
  `192.168.11.223/32`. CORE №40 Job #56 подтвердил
  CloudflareWARP вместо прямого `eth0` и HTTPS 200
  для CORE → HOME PBS. Jobs #58–#61 подтвердили авто-переподключение,
  active audit и идемпотентность.
- CORE №40 сохранил TLS fingerprint HOME PBS для своего ранее
  действующего направления (не является fingerprint CORE PBS):
  `69:B6:A4:47:18:B2:B9:87:F3:40:2B:16:96:04:73:E9:8B:E0:5E:53:5F:DA:F2:11:EA:56:D2:ED:08:CB:54:DB`.
  Для HOME Push потребуется отдельно проверить сертификат
  **CORE PBS**.
