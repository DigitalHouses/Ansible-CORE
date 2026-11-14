# CORE №31 — Create / Recreate + Import

**Назначение:** на пустом CORE PVE после bootstrap создать с нуля Debian 13 Media/PBS VM2243 (`192.168.11.243`). Для повторной установки того же CORE VM2243 — удалить только управляемый виртуальный системный диск, заново создать VM и импортировать существующий физический ZFS-диск.

## Единый сценарий

CORE Semaphore → **31-CORE Media/PBS — Create/Recreate + Import**:

- **01 — Audit** (по умолчанию): определить, существует ли VM2243, ничего не менять.
- **02 — Apply**: если VM2243 отсутствует — **Create**; если существует — **Recreate**. Диск только **Import**, режим Erase отсутствует.

Источник кода — `DigitalHouses/Ansible-CORE/playbooks/core-media-fresh.yml`. Проверенные нативные блоки (Debian, Cloud-Init, GPU, ZFS, SMB, Plex, Jellyfin, Radarr, Sonarr, Prowlarr, qBittorrent, Filestash, Sambee, PBS и порталы) перенесены **в Ansible-CORE** из `Ansible-HOME`, без вызовов HOME Semaphore или HOME repo при исполнении. Никаких Python-скриптов в ролях и сброса данных ZFS.

## Зафиксированная идентичность CORE

| Ресурс | Параметр |
| --- | --- |
| PVE | `192.168.11.240` |
| VM Media/PBS | `VM2243` |
| IPv4 | `192.168.11.243/24` |
| PVE имя | `mediaserver-dh-core` |
| Ресурсы VM | 2 vCPU, 4 GiB RAM, 64 GiB `local-lvm` |
| GPU PCI passthrough | `0000:2f:00.0` |
| SATA controller PCI passthrough | `0000:2b:00.0` |
| Физический пул | `serzhan-pool` |
| Pool GUID | `18293847766285774524` |
| PBS datastore | `pbs-core`, `pbs-serzhan` |
| Данные приложений и клиент | `serzhan` на исходном ZFS |
| Сеть Tailscale | `accept-dns=false`, `accept-routes=false` |

CORE Site ID — `dh-core`, а старое имя пула `serzhan-pool` сохраняется ради данных. Параметры хранятся в `vars/core-media-deploy.yml`.

## Порядок выполнения Apply

1. Определить наличие VM2243 и проверить физические PCI-устройства. При Recreate — подтвердить работоспособность существующего ZFS/PBS до выключения.
2. До удаления старого системного диска загрузить официальную Debian 13 cloud image и проверить SHA512.
3. Создать новую VM2243 через нативные `qm create`, `qm importdisk`, Cloud-Init и QGA. Поскольку VMID задан только CORE, никаких HOME VM не затрагивать.
4. Установить Debian/ZFS/Intel GPU, выполнить `zpool import -f serzhan-pool` без переформатирования и подтвердить **точный GUID**.
5. Установить новый PBS 4.2+ и восстановить **только** его конфигурацию, TLS/ACL/API-токены из защищённого архива на существующем ZFS. Это **не** восстановление операционной системы из архива.
6. Поставить Tailscale с сохранением прежнего ключевого состояния и отключённым перехватом DNS/маршрутов, затем нативные SMB и Media-приложения с пользовательскими учётными записями на ZFS.
7. Проверить услуги и PVE/Guest acceptance, затем отдельно через CORE №40/50/71 подтвердить центральное резервирование и сеть.

**Операции `qmrestore`, `wipefs`, `sgdisk`, `zpool destroy` в этом сценарии отсутствуют.** Неподдерживаемая чистая установка без существующего SATA-пула отклоняется: режим `Import` предполагает реальные физические данные. Секреты из CORE Semaphore и архив PBS на ZFS остаются закрытыми.

## История

Старые Jobs #114/#115 использовали **неверную** реализацию Recreate через `qmrestore` системного диска. Эта ветка удалена из исполняемого CORE-пайплайна; старый архив остаётся резервной копией и не используется при создании Debian. Задача №31 теперь предназначена для чистого `Create/Recreate + Import`.
