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

API Token проверяется через стандартный Cloudflare endpoint
`/user/tokens/verify`, если токен доступен в задаче. Это **не**
проверка прав на изменение Cloudflare. Наличие пары enrollment
Client ID/Secret проверяется без попытки регистрировать устройство;
их действительность проверим при фактическом enrollment в CORE №40.

## Следующие расширения

Для CORE №50 добавим read-only PBS source identity/tokens каждого
готового HOME. HOME создаёт и выдаёт эти credentials в своём
профильном проекте; CORE №05 сохраняет их для своих задач.
PBS Remote, Pull Sync, Verify и restore — зона ответственности №50.

Не хранить Cloudflare/PBS secrets в репозитории, файлах в DEV,
командной строке и журналах. Не копировать существующие HOME
credentials без отдельной операции.

## Приёмка

1. Запустить №00 — появится шаблон №05, не меняя №40 и №50.
2. Запустить №05 с пустыми полями — read-only аудит группы
   `changed=0`, результат `NOT_CONFIGURED`.
3. Ввести хотя бы одно реальное значение в №05;
   проверить readback и отсутствие секретов в output.
4. Повторный запуск с пустыми полями не должен обнулять значения.
5. Убедиться, что №40 и №50 всё ещё ссылаются на ту же Variable Group.
