# CORE №71 — Tailscale PVE + PBS

## Назначение

Единый штатный Tailscale на центральных узлах DigitalHouses:

| Узел | LAN | Управление |
| --- | --- | --- |
| CORE PVE | `192.168.11.240` | SSH из CORE Semaphore |
| CORE PBS, VM2243 | `192.168.11.243` | QEMU Guest Agent через CORE PVE |

Cloudflare Tunnel + Access отдельно обслуживают доступ к веб-сервисам.
Задача №71 не изменяет Cloudflare, PBS datastores, конфигурацию VM
или HOME и не выполняет глобальный `apt upgrade`.

## Semaphore

Шаблон **`71-Tailscale`**; playbook `playbooks/core-tailscale.yml`.

- `DH_CORE71_ACTION`: `audit` (по умолчанию), `install`, `configure`, `join`, `update`.
- `DH_CORE71_TARGET`: `pve`, `pbs`, `both` (по умолчанию).
- Секрет `DH_TAILSCALE_AUTH_KEY` из CORE №05 требуется **только** для `join`.
  Передаётся во временном защищённом файле и после входа удаляется.

| Действие | Поведение |
| --- | --- |
| `audit` | Только чтение: установленная версия, подключение к tailnet, DNS и маршрут по умолчанию |
| `install` | Установить официальный stable Tailscale через APT, без входа в tailnet |
| `configure` | Применить безопасный профиль к уже подключённому клиенту |
| `join` | Присоединить незарегистрированный клиент к существующему tailnet |
| `update` | Разово обновить только установленный пакет `tailscale` |

Профиль Tailscale на обоих узлах:

```bash
tailscale set --accept-dns=false --accept-routes=false --exit-node= \
  --advertise-routes= --advertise-exit-node=false --auto-update=true
```

Задача сравнивает локальные DNS и default route до/после изменений;
любой неожиданный сдвиг приводит к ошибке. Не настраиваются
exit node, subnet router и Tailscale SSH. Существующие клиенты не
выходят из tailnet при обычном `configure`.

## Автоматические обновления

- Встроенный Tailscale auto-update включается через `configure` или `join`.
- **Никаких расписаний Semaphore** для обновления: прежнее расписание ID 1
  удалено через API, после удаления список расписаний CORE был пуст.
- Действие `update` остаётся для ручного одноразового запуска.
- HOME использует такой же встроенный механизм.
- Для Cloudflare Tunnel используется отдельный стандарт Debian
  `unattended-upgrades` (CORE №60), без собственного таймера Semaphore.

## Подтверждённая приёмка

- CORE №71 **Job #175**: `configure/both`, `success`, `failed=0` — включён
  встроенный auto-update на PVE и PBS; Tailscale версии `1.104.7`,
  оба клиента `Running`, DNS и default route без изменений.
- CORE №71 **Job #179**: `audit/both`, `success`, `changed=0`, `failed=0` —
  оба клиента `Running`, DNS и default route без изменений.
- Tailscale addresses при первоначальной приёмке:
  `dh-core-pve` — `100.64.243.13`, `dh-core-pbs` — `100.97.126.67`.
- Проверен прямой CORE PVE ↔ PBS трафик Tailscale; успешность реального
  PBS Push/Restore подтверждается отдельно профильными задачами HOME/CORE.
- Удалены устаревшая операция `migrate`, её task-файл, диагностика
  стороннего VPN-сервиса и устаревшее поле отчёта. История прошлых
  миграций сохранена в Git и журналах Semaphore.

## Источники

- https://tailscale.com/docs/install/linux
- https://tailscale.com/docs/reference/tailscale-cli
- https://tailscale.com/docs/features/client/update
