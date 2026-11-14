# CORE №31 — подготовка Recreate + Import VM2243

**Границы:** только CORE PVE `192.168.11.240` и CORE
Media/PBS VM2243 `192.168.11.243`. Репозиторий
`DigitalHouses/Ansible-CORE`. HOME VM2223 и HOME Semaphore не трогать.

## Что подтверждено живым аудитом 14.11.2026

- VM2243 `mediaserver-serzhan` (legacy, ожидаемое новое
  `mediaserver-dh-core`), `protection=1`, 2 vCPU, 4GiB RAM.
- Виртуальный системный диск `local-lvm:vm-2243-disk-0`, 64GiB,
  ext4 с ~11GiB используемого места; отдельно cloud-init volume.
- Два PCI passthrough устройства: GPU `0000:2f:00.0`,
  SATA `0000:2b:00.0`.
- Физический ZFS-пул внутри гостя `serzhan-pool`, ONLINE,
  3,62TiB, свободно ~2,33TiB.
- Данные `pbs-core` (~101GiB) и `pbs-serzhan` (~317GiB) лежат
  на ZFS, **не** на rootfs.
- `/etc/proxmox-backup`, `/root/.digitalhouses/core50`,
  `/var/lib/plexmediaserver`, `/var/lib/tailscale`, состояния
  Arr/Jellyfin/qBittorrent — на системном ext4.
- CORE PVE job `dh-local-pbs-serzhan` исключает VM2243.
  Наличие snapshots в PBS не означает наличие резервной копии
  загрузочного диска этой VM.
- CORE PVE `/var/lib/vz` на системном NVMe: 76GiB свободно
  по состоянию аудита. Место проверяется повторно перед архивированием.

### Почему импорт ZFS сам по себе недостаточен

Без сохранения ключей `proxy.pem/proxy.key`, PBS ACL,
`token.shadow`, `user.cfg`, `authkey.*` и файлов CORE50
изменятся PBS TLS fingerprint и/или API авторизация HOME Push/Restore;
могут потеряться настройки приложений, Plex state и tailnet identity.
Все они находятся вне передаваемого SATA-диска.

## Semaphore №31

**01 Аудит** (`DH_CORE31_ACTION=audit`, default):

- pinned CORE bootstrap profile, CORE .243 и VM2243;
- наличие защищённой VM, boot disk, PCI passthrough и QGA;
- онлайн ZFS, пути обоих PBS datastore;
- приватные ключи и секреты PBS существуют на ext4, данные PBS на ZFS;
- локальное расписание и исключение VM2243;
- доступное свободное место NVMe и имеющиеся native VM archives.

**02 Защита** (`DH_CORE31_ACTION=protect`) запускается отдельно:

1. создаёт в guest root-only `0700` каталог
   `/serzhan-pool/digitalhouses/core31-recreate`;
2. сохраняет критичные PBS/CORE50/Tailscale/Media настройки в
   `guest-state-<UTC>.tar.gz` и SHA256; оба файла `0600`;
   содержимое никогда не печатается в Semaphore;
3. создаёт PVE native `vzdump 2243 --mode snapshot --compress zstd
   --dumpdir /var/lib/vz/dump` **только виртуального boot disk**;
   ZFS passthrough PCI диски этот архив не содержит;
4. проверяет наличие архива, тестирует zstd, считает SHA256;
   сохраняет архив и контрольную сумму с доступом root-only.

**Внимание:** `protect` — hot/crash-consistent checkpoint живого гостя,
а не доказательство корректного восстановления всех SQLite/приложений.
Перед разрушительным cutover требуется отдельная согласованная
offline-consistent копия и проверка восстановления.

Если полноценный PVE архив уже имеется, действие защиты останавливается
без перезаписи, чтобы не создавать молча неограниченные копии.

## Текущая граница реализации

**Действия `recreate` / `import` намеренно недоступны.**

В CORE №30 сейчас E2E сервисов и repair portal, а не unattended
commissioning Debian/PBS/Plex/Arr/Jellyfin. Простое
`qm destroy 2243` уничтожило бы не защищённое ZFS состояние системной
части приложения. До добавления *CORE-only* native Ansible
reprovisioning/restore-контракта и теста отката ни один playbook не
вызывает `qm destroy`, `qmrestore`, `zpool import`,
`wipefs` или `sgdisk`.

В отдельном следующем изменении реализовать:

1. точную cold backup/rollback-проверку с сохранением старой VM
   (нельзя считать, что rootfs уже копируется расписанием);
2. создание Debian 13 VM2243 с именем `mediaserver-dh-core`,
   адресом `.243` и прежним контроллером SATA/GPU;
3. импорт существующего ZFS без erase, сохранение идентичности pool
   GUID, PBS datastore и всех snapshots;
4. штатную CORE настройку приложений, сервисов, PBS ACL, токенов,
   TLS ключей и Tailscale; без включения автоматических удалений;
5. E2E приёмку через CORE №30/40/50/71 и тестовый Restore в
   отдельный VMID, потом переход к штатной работе.

**Запрещено:** использовать HOME tasks/Semaphore для создания CORE,
удалять `pbs-serzhan`, менять CORE PBS TLS fingerprint/токены,
включать автоматический Prune/GC, выполнять `erase`,
запускать bootstrap на уже действующем CORE.
