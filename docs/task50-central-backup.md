# №50 — Central Backup

**Назначение:** эксплуатация централизованного резервирования домов в
`dh-core / Media Server + PBS — VM2243, 192.168.11.243`.
Не устанавливает PVE, PBS, VM, ZFS и Cloudflare-транспорт — это
инфраструктурные зависимости задачи №40 и отдельного HOME №70.

## Граница ответственности

- **№40 CORE Infrastructure:** аудит CORE PVE/VM/PBS, подготовка
  `serzhan-pool/pbs-core` и проверка базового маршрута.
- **№50 Central Backup:** PBS Remotes для HOME, отдельные namespaces,
  Pull Sync Jobs, их запуск/расписание, retention, Prune, GC, Verify,
  мониторинг и E2E-восстановление.
- **HOME №70 и другие HOME задачи:** Cloudflare исходящий туннель
  на каждом HOME, доступ PBS и выдача разрешённых credentials. CORE не
  меняет HOME через №50.

## Реализованный этап: audit (без изменений)

`playbooks/core-backup.yml` запускается только из существующего
`dh-core / Semaphore — CT1241, 192.168.11.241`. Проверяет закреплённую
CORE PVE, работающую VM2243, наличие `pbs-core` и `pbs-serzhan`,
читает PBS Remote и Sync Job конфигурацию. Не запускает синхронизацию,
не меняет credentials, маршруты, расписания, ZFS, datastore или данные.

Для первого этапа у №50 **нет Survey**: единственное доступное действие —
безопасный аудит. Режимы `configure`, `sync`, `test` появятся после
реальной реализации, а не как неработающие пункты интерфейса.

## Следующие этапы — не реализованы

1. Убедиться, что CORE PBS VM2243 действительно достигает HOME PBS
   через Cloudflare private route, включая пилот `serzhan-home`.
   Прямое LAN-подключение не является подтверждением.
2. Получить от соответствующего HOME штатный read-only PBS API token
   с доступом ко всем нужным backup groups и проверить TLS fingerprint.
   Секреты — только в Semaphore, не в Git и не в Survey.
3. Создать PBS Remote и отдельный namespace HOME на `pbs-core`,
   а также Pull Sync Job с `remove-vanished=false`, без расписания
   до успешного ручного пилота.
4. Проверить синхронизацию, Verify, фактическое тестовое восстановление
   и сравнение данных; только затем согласовать schedules/retention/GC.
5. Добавлять остальные HOME по той же модели без изменения исходных
   backup jobs на домах.

**Критерий E2E:** не статус `success`, а полное тестовое восстановление
из `pbs-core` с подтверждением целостности и повторным Pull без потери
или дублирования данных.

## Сохранение истории Semaphore

№40 переименовывается в **том же шаблоне ID 2**, оставаясь с прежним
`playbooks/core-pbs.yml` и Survey `audit/prepare`.
№50 создаётся как новый шаблон через каталог №00. Существующие
задания и история не удаляются.

## Живая приёмка разделения задач — 12.11.2026

- `dh-core / Semaphore — CT1241, 192.168.11.241`: существующая
  №40 переименована **на том же шаблоне ID 2**. Сохранены исходная
  история запусков, repository ID 2, inventory ID 2, environment ID 1.
- №00 Job #15: `success`, создала новую №50, шаблон ID 3.
- №50 Job #16: `success`, `runner ok=2 changed=0 failed=0`,
  `core50_pve ok=9 changed=0 failed=0`.
- Реальный PBS в `dh-core / VM2243, 192.168.11.243`:
  `pbs-core` и `pbs-serzhan` присутствуют;
  `CORE50_REMOTE_COUNT=0`, `CORE50_PULL_SYNC_JOB_COUNT=0`.
- №40 Job #17 (`audit`): `success`, `runner ok=2 changed=0 failed=0`,
  `core40_pve ok=10 changed=0 failed=0`.
- Повторный №00 Job #18: `success`; шаблоны ID 1/2/3 сохранены,
  дубликаты не появились.
- Полный backup E2E (Pull Sync, Verify, восстановление) **не выполнен**:
  транспорт Cloudflare и PBS source credentials ещё не готовы.
