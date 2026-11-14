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


## Live CORE protection acceptance — 14.11.2026

- CORE №00 Job **#104** registered the new №31 Semaphore template, ID **7**.
- №31 `audit` Job **#109**: `success changed=0 failed=0`.
  Exact VMID, .243, GPU/SATA passthrough, drive serial
  `PK1331PAGH7VHS`, ZFS GUID `18293847766285774524`,
  `pbs-core`, `pbs-serzhan`, rootfs credentials all passed.
- №31 `protect` Job **#112**: **success**;
  runner `ok=4 changed=0 failed=0`,
  CORE PVE `ok=34 changed=4 failed=0`.
- Native PVE rollback archive:
  `/var/lib/vz/dump/vzdump-qemu-2243-2026_11_14-11_15_11.vma.zst`,
  **4,855,813,871 bytes**, `root:root 0600`, alongside
  matching `.sha256`; `zstd -t` passed.
- Preserved guest ZFS secret/app-state archive:
  `/serzhan-pool/digitalhouses/core31-recreate/guest-state-20261114T061448Z.tar.gz`,
  **281,750,224 bytes**, `root:root 0600`, directory
  `root:root 0700`. Its `.sha256` verified independently and
  `tar -tzf` showed required PBS configuration, token files and
  application state paths.
- PVE checksum `sha256sum -c` independently returned **OK**; PBS
  services remained `active`; ZFS pool remained `ONLINE` with
  unchanged GUID; VM2243 remained `running`.
- Safely resolved pilot issues without destructive action:
  `-o name,health,guid` argv quoting, YAML Bash array, and removal
  of inherited ZFS directory setgid bit. All changes merged in
  Ansible-CORE PRs **#11–#16**.

**Acceptance boundary:** these are intact *hot* checkpoints,
**not** proof of cold/offline consistency, standalone system rebuild,
disk-loss DR, or a successful VM restore. Full Recreate + Import
remains blocked by the missing CORE native fresh-provisioning workflow.


## CORE №31 action 03 — Recreate + Import (2026-11-14)

This native CORE-only action is now implemented as
`DH_CORE31_ACTION=recreate-import`. It **recreates** the Proxmox VM2243
from the already protected `vzdump` virtual system-disk archive.
It is **not a fresh Debian install** and deliberately retains installed
apps, PBS identity, credentials and Tailscale configuration.

The action validates the archive SHA256, preserved ZFS credential
archive, SATA serial, ZFS GUID and PBS TLS fingerprint. It then
gracefully shuts down VM2243, removes its protected VM config and
owned **virtual** OS/cloud-init disks (never the passed-through SATA),
and creates VM2243 using native `qmrestore` to `local-lvm`. The
new PVE VM name is `mediaserver-dh-core`; VMID and address remain
`2243 / 192.168.11.243`. After boot it validates physical pool GUID,
`pbs-core`/`pbs-serzhan` datastore paths, unchanged PBS certificate
fingerprint and working PBS HTTPS API.

The previously saved archive remains under `/var/lib/vz/dump` and
is **not deleted**. This is a service interruption. A failed restore
requires recovering from the retained archive; never use `erase`.

For a **fresh Debian OS** rebuild, a separate provisioning pipeline
would be needed. Do not claim this action reinstalls Debian or
recreates native media applications.
