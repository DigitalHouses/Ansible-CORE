# DigitalHouses / Ansible-CORE

Independent native Ansible + existing Semaphore for central **dh-core** infrastructure.

- **00** — reconcile CORE Semaphore catalog.
- **05-Ввести и проверить credentials** — maintain shared native Semaphore credentials for all CORE tasks.
- **30-CORE Media E2E** — read-only end-to-end validation of canonical VM2243/.243 identity, all portal links, native Media services, SMB, HTTPS and NoCloud; optional surgical portal/IP repair.
- **31-CORE Media/PBS — Create/Recreate + Import** — fresh Debian 13 VM2243 install, original `serzhan-pool` import (never erase), PBS identity and native Media services; supports `audit`, `apply`, and `resume`. Clean-install acceptance: Job #122 PASS (14 Nov 2026).
- **40-CORE Infrastructure** — audit CORE PVE/PBS, prepare `pbs-core`, or explicitly migrate the active CORE PVE backup to `pbs-core/dh-core` and retire legacy PBS registrations without deleting old ZFS snapshots.
- **50-Central Backup** — audit central PBS; pilot serzhan-home namespace and scoped Push/Restore tokens are provisioned. 21 incoming snapshots have passed a native manual PBS Verify (Job #128, 16 Nov 2026). Retention/Prune, automatic Verify/GC, freshness monitoring and E2E Restore remain outstanding. HOME initiates native **Push Sync** into CORE; no CORE Pull Jobs.
- **71-Tailscale** — manage CORE PVE/PBS Tailscale client via separate audit,
  install, configure, join, one-time PBS migration and stable-only update actions.

HOME setup, HOME Media Server and HOME Cloudflare tunnel are **excluded**.
CORE never provisions HOME from this repository. CORE PVE/PBS use a common Tailscale tailnet; HOME №34 confirmed
HOME PBS → CORE PBS route and real Push (21 snapshots). CORE Verify succeeded;
actual Restore is still pending. HOME independently
runs local backups.
Backblaze B2 is deferred (source HOME vs CORE not decided).

Resource IDs and naming: `docs/core-resource-standard.md`.
**PBS topology (verified 16 Nov 2026):** HOME PBS VM2223 (`.223` on PVE `.220`) owns `pbs-serzhan`; CORE PBS VM2243 (`.243`) registers only `pbs-core`, with namespaces `serzhan-home` (incoming HOME Push) and `dh-core` (own CORE PVE backups). CORE #40 Job #134 migrated the 02:00 job; read-only CORE #40/#50 Jobs #135/#136 passed. The obsolete CORE ZFS dataset `serzhan-pool/pbs-serzhan` (318 GiB) remains safely preserved but is not a registered PBS datastore.

CORE VM2243 recovery prerequisites: `docs/task31-core-recreate-import.md`.
Latest CORE runtime audit: `docs/core-postinstall-audit-2026-11-16.md`.

See `bootstrap/README.md`, `docs/repository-split.md`,
`docs/task05-credentials.md`, `docs/task40-central-pbs.md`,
`docs/architecture-central-backup.md` (architecture source of truth),
`docs/task50-central-backup.md` and `docs/task71-tailscale.md`.
Original source: `DigitalHouses/Ansible-3` is archived for history.

### CORE DH Stats (№60)

CORE DH Stats работает на CT1245/IP `192.168.11.245`; туннель `dh-core` принимает `telemetry.digitalhouses.vip` через защищённый origin `http://192.168.11.245:8082`, локальный dashboard на `:80`. Действия №60: **Создать** и **Обновить** (без удаления статистики). Подробнее: [docs/task60-dh-stats.md](docs/task60-dh-stats.md).

## CORE lifecycle (26.11.2026)

S23: component-oriented Create/Update; Media/PBS additionally has an independent Import/Erase selection used only by Create. Update bypasses the VM and ZFS lifecycle entirely. Current CORE Media/PBS Create supports the preserved-pool Import path; Erase intentionally fails before contacting PVE pending a complete fresh PBS and Tailscale identity flow. Update upgrades existing APT-managed services, applies PBS capacity ACL and Tailscale auto-update, without disk operations. Non-APT releases remain under their existing native mechanisms/pinned releases; no forced reinstall.

New CORE №10 configures Tailscale and installs/updates PVE Agent using the official CLI and native auto-update. First-install MQTT credentials are optional fields in CORE №05. Existing agent settings and UPS configuration are preserved. CORE №50 Create prepares the selected HOME receiver; Update reconciles its native maintenance. CORE №60 uses Create/Update with Update as default; never deletes its embedded DB.

Legacy CORE №30/40/71 remain available until their functions are completely migrated; do not run them as routine deployment steps. No HOME repository is changed.
