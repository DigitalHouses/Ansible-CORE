# CORE №71 — Tailscale (PVE + PBS)

**Назначение:** обслуживание Tailscale на центральных узлах без изменения
их обычного DNS, default route, PVE/PBS сервисов и работающего Cloudflare.
Код относится только к `DigitalHouses/Ansible-CORE`.

## Фактическая инфраструктура (13.11.2026)

| Узел | ОС | IP | Tailscale перед внедрением |
| --- | --- | --- | --- |
| CORE PVE (ASRock) | Debian 12 bookworm | `192.168.11.240` | отсутствует |
| CORE PBS VM2243 | Debian 13 trixie | `192.168.11.243` | отсутствует, **WARP активен** |

CORE PVE и CORE PBS имеют обычный default route через локальный роутер
`192.168.11.1`. PBS получает команды через штатный QEMU Guest Agent:
не создаём дополнительный SSH-ключ/туннель до гостя.

## Semaphore

Новый шаблон **`71-Tailscale`**, playbook
`playbooks/core-tailscale.yml`, 2 Survey:

1. `DH_CORE71_ACTION`: `audit` (по умолчанию), `install`,
   `configure`, `join`, `update`.
2. `DH_CORE71_TARGET`: `pve`, `pbs`, `both` (по умолчанию).

**CORE №05** содержит дополнительный native secret
`DH_TAILSCALE_AUTH_KEY`. Только при `join` этот ключ используется
для входа в **существующий** tailnet. Пустой ключ = задача `join`
завершается без сетевых изменений. Параметр передаётся как временный
защищённый файл с последующим удалением, не как значение CLI.
Предпочтительнее одноразовый ключ для отдельно выбранного узла.
Запись credentials в Git/логи запрещена.

## Поведение действий

- **audit:** read-only версия пакета, статус клиента, default route
  и DNS; для PBS дополнительно active/inactive Cloudflare WARP.
- **install:** официальный stable APT repository для Debian
  bookworm/trixie, установка **только** пакета `tailscale`;
  не логинится в tailnet и не меняет Tailscale routes.
- **configure:** доступно только для уже зарегистрированного
  клиента, применяет одинаковый безопасный профиль.
- **join:** через существующий CORE №05 secret; не трогает уже
  подключённый узел. На PBS **запрещено**, пока `warp-svc` active.
  Это предотвращает конфликт WARP/Tailscale в 100.x сети.
- **update:** обновляет **только уже установленный** Tailscale
  из официального stable APT repo. Не устанавливает Tailscale
  на отсутствующие узлы и не делает `apt upgrade`.

Безопасный профиль:

```bash
tailscale set --accept-dns=false --accept-routes=false --exit-node= \
  --advertise-routes= --advertise-exit-node=false --auto-update=false
```

Tailscale IP из 100.64.0.0/10 сохраняется; маршрут до tailnet
не считать «перехватом всего интернета». Не включать subnet
router, exit node и Tailscale SSH по умолчанию.

## Переход с Cloudflare WARP на CORE PBS

**Отдельная миграция:** CORE №71 не удаляет и не останавливает
`warp-svc`, не редактирует Cloudflare Zero Trust и не меняет CORE №40.
Сначала провести безопасную миграцию ранее принятого маршрута CORE →
HOME, затем убедиться, что `warp-svc` неактивен, и только тогда
`71 / join / pbs`. Удаление WARP-пакета, Device Profile, неактуальных
№40 действий — после отдельного принятия миграции.

Cloudflare Access/Tunnel оставляем для административных веб-интерфейсов.
Cloudflare и Tailscale обновлять в **разные** окна.

## Плановое обновление

Предполагается отдельное **Semaphore Schedule** для
`71 / update / both`, еженедельно в согласованное окно, не совпадающее
с большой PBS-синхронизацией. Пока оба клиента ещё не установлены
и PBS WARP не мигрирован, не активировать автоматическую установку,
`join` или `update` на PBS. До утверждения времени расписания
разрешён ручной запуск `update` по отдельному узлу.

Отсутствие установленного клиента при `update` означает `skip`,
а не скрытую установку. Встроенное `tailscale auto-update`
отключается при `join`/`configure`; расписание Semaphore
становится единственным управляемым механизмом обновления.

## Критерии приёмки

1. `71 / audit / both` работает без изменений, показывает
   2 узла, статусы Tailscale и WARP.
2. `71 / install / pve`, затем `join / pve` только при
   наличии секретного auth key в №05, без повреждения SSH/DNS/default route.
3. Повторный `71 / install` не переустанавливает пакет,
   а `update` повторно без новой версии имеет `changed=0`.
4. Для PBS сначала миграция с WARP, затем `install/join`.
5. Проверить `tailscale ping`, стабильность соединения PVE/PBS
   и реальный PBS Push/Restore в профильных №50/Ansible-HOME.
6. После успешного E2E — зафиксировать окно еженедельных обновлений
   и создать/включить Semaphore Schedule.

**Не считать приёмкой:** наличие бинарника или успешный `apt`
без реального tailnet Connection и передачи данных.

## Документация

- https://tailscale.com/docs/install/linux
- https://dl.tailscale.com/stable/
- https://tailscale.com/docs/reference/tailscale-cli
- https://tailscale.com/docs/features/client/update
- https://tailscale.com/docs/reference/interoperability

## Живая приёмка каталога и read-only аудита (13.11.2026)

- CORE Git `main`, commit `0faee58`: добавлены playbook, задачи
  PVE/PBS, Semaphore №71 и secret-поле №05.
- Semaphore №00 Job **#65**: `success`. Создан №71
  `71-Tailscale`, template ID **5**, 2 Survey (`action`, `target`);
  прежние шаблоны и история сохранены. №05 получил пятое
  Secret Survey-поле; auth key **не вводился**.
- Semaphore №71 Job **#66**, `audit / both`: `success`,
  `changed=0`, `failed=0`; CORE PVE `tailscale=NOT_INSTALLED`,
  CORE PBS VM2243 `tailscale=NOT_INSTALLED`, `WARP=ACTIVE`,
  для обоих `DEFAULT_ROUTE_AND_DNS=UNCHANGED`.
- **Не выполнялись:** установка пакетов, вход в tailnet,
  настройка маршрутов, удаление WARP, запуск реального PBS Push/Restore
  и создание Semaphore Schedule обновлений.

## Подключение CORE PVE (13.11.2026)

- Job #68: `install/pve`, `success`, Tailscale stable `1.104.7`;
  локальные DNS и default route не изменены.
- Job #69: `join/pve` завершился до подключения, поскольку №71
  некорректно читал native Ansible secret как environment variable;
  исправлено в Git `eb1f4ae`.
- Job #70: `join/pve` завершился с ошибкой неподдерживаемого
  `--auto-update` в `tailscale up`; этот флаг теперь применяется
  только командой `tailscale set` (Git `f488591`).
- Job #71: `join/pve`, **success**, Tailscale `Running`,
  assigned IP **`100.64.243.13`**, no DNS/default route changes,
  `CorpDNS=false`, `RouteAll=false`, `AutoUpdate.Apply=false`,
  exit node отсутствует. Temporary auth-key file удалён по playbook.
- `tailscale ping`: `pve-shahristan` direct `192.168.11.220:41641`
  (~1ms); `pve-jodar` через DERP(nyc), `pve-ruslan`
  через DERP(waw). Для больших PBS Push Sync проверить реальный
  throughput; не считать успешный ping гарантией direct.
- CORE PBS VM2243 не изменён; `warp-svc` остаётся `active`.
- Tailscale node сейчас показывается под автоматически определённым
  именем `pve`; при необходимости задать уникальное имя в tailnet
  отдельно, не меняя системный hostname Proxmox.

## CORE PBS — переход без пересоздания VM (13.11.2026)

Read-only инспекция показала, что VM2243 — совмещённый сервер,
а не пустая PBS VM: passthrough ZFS pool `serzhan-pool` 3.62 ТБ,
занято около 1.18 ТБ, `pbs-serzhan` ~316 ГБ,
`pbs-core` ~24.3 МБ, documents ~334 ГБ, media ~357 ГБ.
Поэтому **recreate + import только ради смены VPN не выполняем**:
никаких операций с ZFS, VM-дисками и datastore.

- Job #72: `install/pbs`, ошибка вызова QEMU Guest Agent
  при установке пакета; проверка после показала фактически
  установленный Tailscale `1.104.7`, работающие QGA и WARP.
- Обработка кратковременного перезапуска QGA исправлена
  в Git `9672d5a`: проверять наличие пакета после восстановления связи.
- Job #73: `install/pbs`, **success**, `changed=0`,
  `failed=0`, Tailscale `NeedsLogin`, WARP `ACTIVE`,
  DNS/default route без изменений.

### Однократная миграция PBS

В №71 добавлено действие **`migrate`**, допустимо
**только при `target=pbs`**. Использует секрет из CORE №05,
проверяет установленный Tailscale и активный WARP, останавливает
и отключает `warp-svc` (пакет пока оставляет для отката),
подключает `dh-core-pbs` к tailnet, проверяет связь с
`dh-core-pve` `100.64.243.13`, status `Running`, маршруты
и локальный DNS. При ошибке делает `tailscale down` и
**пытается восстановить WARP**; о необходимости ручной проверки
сообщает явно.

Удаление WARP пакета и исключение его действий из №40 — отдельный
последующий шаг **только после успешного теста транспорта**.
Не удалять Cloudflare Tunnel/Access, не трогать HOME №70.

## Финальная приёмка CORE PBS (13.11.2026)

- CORE №00 Job #74 добавил Survey `migrate` в №71.
- CORE №71 Job **#75**, `migrate / pbs` — **success**,
  `failed=0`, `CORE71_TAILNET=Running`,
  `CORE71_WARP=INACTIVE`, DNS/default route `UNCHANGED`.
- CORE PBS в tailnet: **`dh-core-pbs`**, `100.97.126.67`.
  CORE PVE: `dh-core-pve`, `100.64.243.13`.
- Связь CORE PVE ↔ PBS **direct** (локальный маршрут
  `192.168.11.243:41641`), Tailscale API PBS `:8007` и
  LAN API PBS `:8007` возвращают HTTP `401` на запрос без
  авторизации (PBS сервис отвечает).
- Пакет `cloudflare-warp` удалён, затем конфигурационные остатки
  очищены `apt-get purge`; `dpkg -s cloudflare-warp` сообщает
  `not installed`, unit `warp-svc` удалён.
- `serzhan-pool`, `pbs-core`, `pbs-serzhan`, media/doc и VM
  не затронуты; `recreate + import` **не выполнялся**.
- CORE №40 теперь обслуживает только инфраструктуру и datastore;
  устаревшие WARP-модули удалены из рабочей версии репозитория.
  Старые Git commits и история Semaphore остаются.
- **Предстоит:** проверить HOME PBS → CORE PBS по Tailscale и
  настоящий Push/Restore, включить автоматический CORE №71 `update`
  после проверки Schedule. Cloudflare Zero Trust device profile
  прежнего PBS не удалялся.
