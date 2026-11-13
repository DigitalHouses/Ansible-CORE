# DigitalHouses Central Backup — целевая архитектура (решение 13.11.2026)

**Статус:** архитектура принята; CORE-пилот `serzhan-home` создан в
`pbs-core` с двумя ограниченными токенами Push/Restore (CORE №50 Job #82).
HOME Push Sync, E2E Restore, регулярные retention/Verify и №10 Registry
ещё **не реализованы**. Ранее намеченная модель CORE Pull отменена.

## 1. Принцип

**Каждый HOME автономен и инициирует передачу собственных резервных копий
в центральный PBS.** CORE принимает, хранит, проверяет и даёт возможность
восстановления; CORE не должен постоянно опрашивать HOME PBS для Pull Sync.

```text
HOME (для каждого дома)
  PVE --backup job--> локальный HOME PBS datastore
                               |
                               | штатный PBS Push Sync, запускает HOME
                               v
CORE PBS VM2243 / 192.168.11.243:8007
  datastore: pbs-core
    namespace: serzhan-home  -> vm/, ct/, host/ и их snapshots
    namespace: arman-home    -> vm/, ct/, host/ и их snapshots
    namespace: ruslan-home   -> ...
```

Это **PBS namespaces**, а не отдельные ZFS datastores или самостоятельные
каталоги файловых архивов. Один общий datastore `pbs-core`, один
корневой namespace на HOME; одинаковые VMID разных домов разделены.
Второй уровень (`ha`, `pve`, `docs`) не создавать без необходимости.
Существующий legacy datastore `pbs-serzhan` на CORE не менять.

## 2. Разделение ответственности

| Область | HOME | CORE |
| --- | --- | --- |
| Локальные PVE Backup Jobs, локальный PBS datastore | Создаёт и обслуживает | Не изменяет |
| Локальная retention/prune/GC/verify | Управляет | Не изменяет |
| Push Sync | Инициирует и запускает штатный PBS Sync Job | Принимает snapshots в namespace HOME |
| Retention / Prune центральных копий | Не управляет | Отдельная политика на каждый namespace |
| Verify центральных snapshots | Не управляет | Выполняет на центральном PBS |
| GC центрального datastore | Не управляет | Выполняет для всего `pbs-core` |
| Восстановление | Локально и/или из CORE по необходимости | Хранит и обеспечивает тестовое восстановление |
| Мониторинг | Отправляет результат и события; не зависит от доступности CORE | Следит за свежестью snapshots каждого HOME и ошибками PBS |

Отсутствие новых snapshots в CORE должно считаться проблемой даже без
сообщений от HOME: только отчёты «успешно» недостаточны. Конкретные
пороговые интервалы и расписания определяются при реализации №50.

## 3. PBS Sync и изоляция данных

Пример для пилота `serzhan-home` (source datastore подтверждается
HOME-аудитом, не предполагается по имени):
- **HOME PBS** хранит исходные snapshots в своём локальном datastore.
- На HOME PBS настраивается **Remote** на CORE PBS и Sync Job
  `sync-direction=push`.
- Место назначения: CORE datastore `pbs-core`,
  **`remote-ns=serzhan-home`**.
- Исходный `ns` (включая root/поддерево) выбирается по реальному
  содержимому HOME PBS.
- `remove-vanished=false`: исчезновение локального snapshot
  не должно автоматически удалять его центральную копию.
- Никакие Pull Sync Jobs CORE → HOME для штатного резервирования
  не создаются. CORE не управляет расписанием Push Sync на HOME.

**Полномочия** всех HOME одинаковы по типу: доступ на запись копий
в своё назначение `pbs-core/<home-id>`. Изолированные HOME credentials
предпочтительны для сопоставления отправителя, backup-group ownership
и исключения смешивания данных; различающихся уровней привилегий
для домов не вводим. Секреты — в штатных Semaphore credentials,
не в Git, документах, логах или сообщениях чата.

Проверить на пилоте, что namespaces создаются корректно, snapshot
получает ожидаемого владельца, повторный Push не дублирует данные,
а центральная Prune не удаляет чужие namespaces. Prune/Verify —
namespace-scoped; GC — datastore-scoped.

## 4. Регистрация HOME в CORE

**Запланирована, не реализована:** CORE №10 HOME Registry.
Логическая сущность `home-id` объединяет имя HOME, назначение
`pbs-core/<home-id>`, адреса и параметры центрального управления.
Один HOME регистрируется один раз и потом обновляется; новых
проектов Semaphore на каждый дом не требуется. Реализация
учёта/Variable Groups/Task Templates проектируется отдельно.
Не создавать код №10 только на основании этой заметки.

## 5. Транспорт и будущее MQTT

**Текущий транспорт PBS — Tailscale, общий tailnet DigitalHouses**
(введено 13.11.2026):

- CORE PVE: `100.64.243.13`, узел `dh-core-pve`.
- CORE PBS VM2243: `100.97.126.67`, узел `dh-core-pbs`.
- Проверен прямой Tailscale `CORE PVE ↔ CORE PBS`, PBS `:8007`
  отвечает по tailnet IP; сохранены DNS `192.168.11.1` и default route.
- CORE WARP Traffic-only остановлен и пакет удалён; исторические
  Cloudflare тесты CORE → HOME **не являются** текущим транспортом.
- HOME PBS `serzhan-home` уже в tailnet: `100.88.184.103` (HOME №34
  Job #122 подтвердил маршрут до CORE PBS `100.97.126.67:8007`).
  Реальный Push Sync и Restore через Tailscale **ещё не выполнены**.
- При одинаковых LAN подсетях использовать уникальные Tailscale IP
  соответствующих PBS, не адреса `192.168.11.x` и не короткий
  MagicDNS hostname: Tailscale DNS отключён.
- Cloudflare Tunnel/Access остаются для внешних веб-интерфейсов.
- В будущем HOME передаёт MQTT телеметрию в CORE, вне текущего
  этапа PBS.

## 6. Backblaze B2 — отложено

B2 остаётся **вне текущих задач и внедрения**. Не выбрано,
кто будет инициировать копирование в B2 — HOME, CORE или оба.
Никаких аварийных B2 Jobs, S3 datastores, credentials, ACL, расписаний
и retention в рамках текущей работы не создавать.
При проектировании будущей схемы учесть выход CORE из строя,
но не подменять этим нерешённый выбор.

## 7. Границы задач и критерии приёмки

- **CORE №40:** PVE/PBS инфраструктура, подготовка datastore;
  WARP-действия выведены из эксплуатации.
- **CORE №71:** Tailscale на CORE PVE/PBS и плановые обновления.
- **CORE №10:** будущая регистрация HOME и его назначения в центре.
- **CORE №50:** создание namespace и минимальных Push/Restore токенов
  выполнено для пилота. Retention, Prune, Verify, GC, freshness-мониторинг
  и тестовое восстановление — после реального Push.
- **Ansible-HOME:** локальный PVE/PBS backup, PBS Remote на CORE,
  Push Sync, запуск и проверки отправки. CORE не пишет HOME конфигурацию.

**Пилот `serzhan-home`:**
1. Отдельно подтвердить работающий приватный HTTPS HOME → CORE PBS.
2. Зарегистрировать HOME в CORE и создать `pbs-core/serzhan-home`.
3. Выдать HOME центральные PBS credentials с одинаковой для домов
   ролью и ограничением области записи; настроить HOME Remote/Push Sync.
4. Вручную запустить Push и увидеть реальные snapshots **в правильном**
   namespace CORE без подмены другим HOME.
5. Выполнить повторный Push (идемпотентность), Verify и **реальное
   тестовое восстановление**; проверить сохранность старых центральных
   snapshots при удалении локальной копии.
6. Только после приёмки согласовать расписания/retention и подключать
   другие HOME по одному шаблону.

**Не считать выполненным:** простую доступность порта `:8007`,
успешную задачу без snapshots или прямое LAN-соединение вместо
Cloudflare. CORE `pbs-serzhan` и локальные backup jobs HOME должны
оставаться неизменными.

## 8. Документация PBS

- https://pbs.proxmox.com/docs/managing-remotes.html — native
  Push Sync, направления и mapping namespaces;
- https://pbs.proxmox.com/docs/storage.html — структура namespaces;
- https://pbs.proxmox.com/docs/config/sync/man5.html — sync-direction,
  remote-ns, remove-vanished;
- https://pbs.proxmox.com/docs/command-syntax.html — scoped
  Prune/Verify и datastore GC.
