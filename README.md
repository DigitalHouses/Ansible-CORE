# DigitalHouses / Ansible-CORE

Independent native Ansible + existing Semaphore for central **dh-core** infrastructure.

- **00** — reconcile CORE Semaphore catalog.
- **05-Ввести и проверить credentials** — maintain shared native Semaphore credentials for all CORE tasks.
- **40-CORE Infrastructure** — audit CORE PVE/PBS infrastructure; safely
  prepare dedicated `pbs-core` datastore when explicitly selected.
- **50-Central Backup** — audit central PBS; pilot serzhan-home namespace,
  scoped Push and Restore tokens provisioned. Central retention, Prune,
  Verify, freshness monitoring and E2E restore remain to be implemented.
  HOME initiates native **Push Sync** into CORE; no CORE Pull Jobs.
- **71-Tailscale** — manage CORE PVE/PBS Tailscale client via separate audit,
  install, configure, join, one-time PBS migration and stable-only update actions.

HOME setup, HOME Media Server and HOME Cloudflare tunnel are **excluded**.
CORE never provisions HOME from this repository. CORE PVE/PBS use a common Tailscale tailnet; HOME №34 confirmed
HOME PBS → CORE PBS route; real Push/Restore is not yet tested. HOME independently
runs local backups.
Backblaze B2 is deferred (source HOME vs CORE not decided).

See `bootstrap/README.md`, `docs/repository-split.md`,
`docs/task05-credentials.md`, `docs/task40-central-pbs.md`,
`docs/architecture-central-backup.md` (architecture source of truth),
`docs/task50-central-backup.md` and `docs/task71-tailscale.md`.
Original source: `DigitalHouses/Ansible-3` is archived for history.
