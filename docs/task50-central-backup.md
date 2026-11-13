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
- **CORE №40:** инфраструктура PBS и datastore. WARP удалён;
  рабочий транспорт резервирования — Tailscale (CORE №71).
- **B2:** отложено; не входит в реализацию №50.
- Legacy datastore `pbs-serzhan` на CORE и действующие HOME backup
  jobs не менять.

Равные полномочия HOME означают **одинаковую роль для отправки
резервных копий**, но отдельный namespace каждого дома.
Токены для HOME → CORE создаются на **CORE PBS**, а не на HOME PBS
для входящего CORE Pull. Credentials не хранить в Git или Survey.

## Текущая реализация — аудит и pilot prepare

Шаблон CORE Semaphore №50 (ID 3) сохранён вместе с историей.
Survey `DH_CORE50_ACTION`:

- `audit` (default): штатный read-only аудит без изменения PBS.
- `prepare`: **только пилот `serzhan-home`** — проверить сертификат
  непосредственно на CORE PBS, создать namespace и две независимые
  identities/API tokens с правами в одном namespace.

Namespace: `pbs-core/serzhan-home`.

| Назначение | Auth ID | Роль | Область |
| --- | --- | --- | --- |
| Push | `serzhan-home-push@pbs!core50` | `DatastoreBackup` | `/datastore/pbs-core/serzhan-home` |
| Restore | `serzhan-home-restore@pbs!core50` | `DatastoreReader` | `/datastore/pbs-core/serzhan-home` |

ACL назначается отдельно PBS-пользователю и его token: effective
privileges проверяются после создания. Ни один из токенов не получает
Prune/Modify или доступ к `pbs-serzhan`.

Для создания namespace временно применён bootstrap token с правами
только на `/datastore/pbs-core`; по завершении он отозван, ACL
удалён. **Не создаём ни CORE Pull Job, ни HOME Push Job.**

**Передача секретов (не через чат/Git/логи):** значения `value` двух
токенов находятся во временно сохраняемых файлах только для `root`
на самой CORE PBS VM2243:

- `/root/.digitalhouses/core50/serzhan-home-push.json`
- `/root/.digitalhouses/core50/serzhan-home-restore.json`

Оператор выводит каждый файл только в доверенной CORE PVE-консоли
командой `qm guest exec 2243 -- cat <path>`, переносит `value`
непосредственно в Secret-поля **HOME Semaphore №05**.
Файлы CORE пока сохраняются как root-only контрольная копия
секретов для повторного ввода.
В Git/чат/лог секреты не публиковать. Повторный `prepare`
не ротирует секреты.

**Принято 13.11.2026:**

- CORE №00 Job #81: обновлён Survey №50 без создания нового шаблона.
- CORE №50 Job #82: `prepare`, success, `changed=10 failed=0`.
  Сертификат совпал с независимым HOME TLS SHA256, namespace создан,
  Push/Restore identities, tokens и ACL подготовлены.
- CORE №50 Job #83: повторный `prepare`, success,
  `changed=0 failed=0`; идемпотентность подтверждена.
- HOME №34 Job #122 (по передаче HOME): маршрут Tailscale готов,
  но Remote, Push Job, snapshots и E2E ещё отсутствуют.

## CORE №50 — штатный ручной Verify полученных HOME snapshots

После успешных HOME №34 Jobs **#133** (первый Push) и **#134**
(повторный Push) проверены на CORE PBS **21 snapshot** в
`pbs-core/serzhan-home` (8 VM + 13 CT).
Это подтверждает доставку, но **не** Verify/Restore.

Добавлен Survey `DH_CORE50_ACTION=verify` (действие 03):
создаёт один native `proxmox-backup-manager verify-job` с ID
`core50-serzhan-home`, только если такого задания ещё нет:

- `store=pbs-core`
- `ns=serzhan-home`
- `max-depth=0` — другие namespaces не затрагиваются
- `ignore-verified=true` — повторная проверка пропускает свежие успешные
- `read-threads=1, verify-threads=2` — умеренная нагрузка
- без `schedule`: проверка только по явному запуску №50

Перед выполнением проверяет фактические snapshot manifests, наличие
namespace, конфигурацию существующего verify-job; не переписывает
конфликтующие настройки. Используется штатный PBS Verify
через QEMU Guest Agent VM2243; команда ожидает итоговый `TASK OK`.
Ни prune, ни GC, ни перезапись, ни изменение legacy
`pbs-serzhan` не выполняется.

После успешного Verify остаётся HOME №34 `restore-storage` и
отдельный Restore в свободный тестовый VMID. До Restore E2E
не считается полностью принятым.

---

## Следующий этап — HOME №34 и E2E

1. **Доверенный оператор CORE** извлекает две пары `tokenid/value`
   из root-only файлов на CORE PBS, без публикации в чат/Git/логи.
2. В HOME Semaphore №05 заполняет 5 уже подготовленных полей:
   `DH_INPUT_CORE_PBS_PUSH_AUTH_ID`,
   `DH_INPUT_CORE_PBS_PUSH_TOKEN_SECRET`,
   `DH_INPUT_CORE_PBS_FINGERPRINT`,
   `DH_INPUT_CORE_PBS_RESTORE_AUTH_ID`,
   `DH_INPUT_CORE_PBS_RESTORE_TOKEN_SECRET`.
   Старые unrelated поля оставить пустыми (сохранить).
3. **В Ansible-HOME №34** сделать `prepare`: Remote
   `core-serzhan-home` → CORE `100.97.126.67:8007`,
   `pbs-core` и `remote-ns=serzhan-home` (push direction).
   Исходный datastore `pbs-serzhan`, `remove-vanished=false`.
4. Ручной `push`, повторный `push` на HOME для проверки
   идемпотентности. Расписание Push до E2E не включать.
5. В CORE №50 проверить реальные snapshots в назначенном namespace,
   owner = Push token identity; затем Verify и централизованную
   namespace-scoped retention.
6. На HOME №34 `restore-storage` с отдельным read-only токеном,
   тестовый Restore в **новый** VMID (не затирать действующие VM).
7. Только после успешного E2E разрешить расписания и масштабирование
   на другие HOME. CORE №10 Registry — отдельный будущий проект.

**Критерий E2E:** реальные snapshots `serzhan-home` видны
в `pbs-core`; повторный Push не разрушает историю;
Verify и восстановление успешно выполнены. Успех только задачи
`prepare` не означает работоспособности резервирования.

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

## Контроль после миграции транспорта CORE (13.11.2026)

- CORE №50 Job **#80**: `audit`, `success changed=0 failed=0`.
- `pbs-core` и прежние настройки сохранены, старых CORE Pull Jobs — 0.
- CORE PBS доступен по Tailscale IP `100.97.126.67:8007`;
  контрольный запрос без авторизации возвращает HTTP `401`
  по LAN и tailnet IP (PBS отвечает).
- WARP выведен из эксплуатации в CORE №71; HOME Push в CORE
  пока не выполнялся. `CORE50_HOME_TO_CORE_TRANSPORT=NOT_YET_CONFIRMED`,
  `CORE50_BACKUP_E2E=NOT_RUN` — корректные статусы.

## Проверка реальной API-авторизации Push-токена

После Job #83 выполнено чтение через настоящий PBS client с
`serzhan-home-push@pbs!core50` и секретом, извлечённым внутри
доверенной CORE PBS VM (без передачи значения в вывод инструментов).

- `snapshot list --ns serzhan-home --repository ...:pbs-core`: **PASS**.
- Попытка прочитать legacy `pbs-serzhan` тем же токеном: **DENIED**.
- Тестирование Restore token отдельным API-сеансом ещё не проводилось;
  его effective ACL (`DatastoreReader`, только serzhan-home) проверен №50.

Эта проверка удостоверяет авторизацию, но не заменяет реальный HOME Push
и Restore тестовой VM — они всё ещё ожидают HOME №05 и №34.
