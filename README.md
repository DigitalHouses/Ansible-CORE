# DigitalHouses / Ansible-CORE

Independent native Ansible + existing Semaphore for central **dh-core** infrastructure.

- **00** — reconcile CORE Semaphore catalog.
- **40-CORE Infrastructure** — audit CORE PVE/PBS infrastructure; safely
  prepare dedicated `pbs-core` datastore when explicitly selected.
- **50-Central Backup** — audit existing PBS backup integration; later
  configure and operate HOME Remotes, Pull Sync, verification and E2E restore.

HOME setup, HOME Media Server and HOME Cloudflare tunnel are **excluded**.
CORE uses the finished HOME transport and credentials but never provisions HOME
from this repository.

See `bootstrap/README.md`, `docs/repository-split.md`,
`docs/task40-central-pbs.md` and `docs/task50-central-backup.md`.
Original source: `DigitalHouses/Ansible-3` is archived for history.
