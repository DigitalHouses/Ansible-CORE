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
