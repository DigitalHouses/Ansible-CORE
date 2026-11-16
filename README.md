# DigitalHouses / Ansible-CORE

Independent native Ansible + existing Semaphore for central **dh-core** infrastructure.

- **00** — reconcile CORE Semaphore catalog.
- **05-Ввести и проверить credentials** — maintain shared native Semaphore credentials for all CORE tasks.
- **30-CORE Media E2E** — read-only end-to-end validation of canonical VM2243/.243 identity, all portal links, native Media services, SMB, HTTPS and NoCloud; optional surgical portal/IP repair.
- **31-CORE Media/PBS — Create/Recreate + Import** — fresh Debian 13 VM2243 install, original `serzhan-pool` import (never erase), PBS identity and native Media services; supports `audit`, `apply`, and `resume`. Clean-install acceptance: Job #122 PASS (14 Nov 2026).
- **40-CORE Infrastructure** — audit CORE PVE/PBS infrastructure; safely
  prepare dedicated `pbs-core` datastore when explicitly selected.
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
CORE VM2243 recovery prerequisites: `docs/task31-core-recreate-import.md`.
Latest CORE runtime audit: `docs/core-postinstall-audit-2026-11-16.md`.

See `bootstrap/README.md`, `docs/repository-split.md`,
`docs/task05-credentials.md`, `docs/task40-central-pbs.md`,
`docs/architecture-central-backup.md` (architecture source of truth),
`docs/task50-central-backup.md` and `docs/task71-tailscale.md`.
Original source: `DigitalHouses/Ansible-3` is archived for history.
