# DigitalHouses / Ansible-CORE

Independent native Ansible + existing Semaphore for central **dh-core** infrastructure.

- **00** — reconcile CORE Semaphore catalog.
- **05-Ввести и проверить credentials** — maintain shared native Semaphore credentials for all CORE tasks.
- **40-CORE Infrastructure** — audit CORE PVE/PBS infrastructure; safely
  prepare dedicated `pbs-core` datastore when explicitly selected.
- **50-Central Backup** — audit central PBS and operate per-HOME namespaces,
  retention, Prune, Verify, GC, freshness monitoring and E2E restore.
  HOME initiates native **Push Sync** into CORE; no CORE Pull Jobs.

HOME setup, HOME Media Server and HOME Cloudflare tunnel are **excluded**.
CORE never provisions HOME from this repository. CORE → HOME Cloudflare
transport is already verified; **HOME → CORE PBS transport remains to be
verified** before Push Sync. HOME independently runs local backups.
Backblaze B2 is deferred (source HOME vs CORE not decided).

See `bootstrap/README.md`, `docs/repository-split.md`,
`docs/task05-credentials.md`, `docs/task40-central-pbs.md`,
`docs/architecture-central-backup.md` (architecture source of truth)
and `docs/task50-central-backup.md`.
Original source: `DigitalHouses/Ansible-3` is archived for history.
