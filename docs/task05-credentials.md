# №05 — CORE Credentials

Единая задача ввода и обновления credentials центрального `dh-core`.
Использует **существующую** штатную Variable Group Semaphore
(`dh-core`, project ID 1, group `Empty`, ID 1). Не создаёт новое
хранилище и не переносит HOME-credentials.

## Правило

- Вводить credentials только в Survey №05, а не в №40, №50 или в Git.
- Secret-поля Semaphore защищены и сохраняются как native Variable
  Group secrets (`type=var`); открытое значение не печатается.
- Непустое поле заменяет **только свой** параметр; пустое поле
  сохраняет старый. Неизвестные параметры Variable Group сохраняются.
- Все CORE templates используют общую группу ID 1; новые задачи
  берут нужные `DH_*` переменные из неё, без повторного ввода.
- Отсутствие credentials не блокирует read-only аудит №40/№50.
- При добавлении новых требований расширять **эту же** №05,
  без размножения отдельных форм/хранилищ.

## Первая версия (12.11.2026)

| Поле Survey | Переменная для CORE задач | Тип |
|---|---|---|
| Cloudflare API Token | `DH_CLOUDFLARE_API_TOKEN` | secret |
| Cloudflare Zero Trust team name | `DH_CLOUDFLARE_TEAM_NAME` | env |
| Cloudflare One enrollment Service Token Client ID | `DH_CLOUDFLARE_ENROLL_CLIENT_ID` | secret |
| Cloudflare One enrollment Service Token Client Secret | `DH_CLOUDFLARE_ENROLL_CLIENT_SECRET` | secret |
| Tailscale registration auth key (добавлено 13.11.2026) | `DH_TAILSCALE_AUTH_KEY` | secret |

API Token проверяется через стандартный Cloudflare endpoint
`/user/tokens/verify`, если токен доступен в задаче. Это **не**
проверка прав на изменение Cloudflare. Наличие пары enrollment
Client ID/Secret проверяется без попытки регистрировать устройство;
их действительность проверим при фактическом enrollment в CORE №40.

## Расширение 13.11.2026 — Tailscale

Добавлен native secret `DH_TAILSCALE_AUTH_KEY` в ту же группу
через Survey `DH_INPUT_TAILSCALE_AUTH_KEY`. Только CORE №71
`join` использует его для регистрации нового CORE PVE/PBS в
существующем tailnet. Приоритет одноразовым auth keys; вводить ключ
только при подключении нового узла. В остальных действиях №71
ключ не нужен.

**Изменение архитектуры №50:** ранее планировавшиеся read-only HOME
PBS токены для CORE Pull **больше не требуются**. Теперь HOME
инициирует Push в CORE, CORE №50 управляет своими namespaces и
полученными backup; будущие токены записи HOME в CORE проектируются
отдельно от общего сетевого auth key Tailscale.

Не хранить Tailscale/Cloudflare/PBS secrets в репозитории, файлах DEV,
командной строке и журналах.

## Приёмка

1. Запустить №00 — появится шаблон №05, не меняя №40 и №50.
2. Запустить №05 с пустыми полями — read-only аудит группы
   `changed=0`, результат `NOT_CONFIGURED`.
3. Ввести хотя бы одно реальное значение в №05;
   проверить readback и отсутствие секретов в output.
4. Повторный запуск с пустыми полями не должен обнулять значения.
5. Убедиться, что №40 и №50 всё ещё ссылаются на ту же Variable Group.

## Живая приёмка (12.11.2026)

- CORE Semaphore project `dh-core`, ID 1; прежний `Empty` Variable
  Group ID 1 сохранён. Не создавалось новых групп или секретов.
- №00 Job #20: `success`. Создан №05 `05-Ввести и проверить
  credentials`, template ID 4, с четырьмя Survey-полями.
- №05 Job #21 (пустые поля): `success`, `runner ok=14 changed=0
  failed=0`, `CORE05_UPDATED_FIELDS=0`, все Cloudflare-поля
  `NOT_CONFIGURED`. Ничего не записано.
- Повторный №00 Job #22: `success`, существующие шаблоны
  ID 1/4/2/3 и общее environment ID 1 подтверждены; дубликатов нет.
- В Variable Group после пробного запуска `env_keys=[]`,
  `secrets_names=[]`. Отсутствующие credentials не выдумывались.
- Реальный E2E сохранения и повторного использования **непустых**
  credentials ожидает ввода настоящих значений оператором в №05.
