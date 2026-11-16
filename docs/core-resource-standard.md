# CORE resource addressing and VM/CT identity

Scope: **Ansible-CORE only**. Canonical site ID is `dh-core`; profile is
`core`. Bootstrap stores both on the CORE Semaphore runner in
`/etc/digitalhouses/site-id` and `/etc/digitalhouses/site-profile`.

## Numbering standard

For guests on the CORE `/24` subnet:

- LXC CTID = `1000 + last IPv4 octet`.
- QEMU VMID = `2000 + last IPv4 octet`.
- The CORE address block starts at `.240`.

| Service | CORE last octet | Proxmox ID | Kind |
| --- | ---: | ---: | --- |
| CORE PVE | 240 | physical host | PVE |
| Ansible / Semaphore | 241 | CT1241 | LXC |
| Home Assistant | 242 | VM2242 | QEMU |
| Media Server + PBS | 243 | VM2243 | QEMU |
| PostgreSQL | 244 | CT1244 | LXC |

The common `/24` prefix comes from the pinned CORE PVE network, not
from a hardcoded guest subnet. Current CORE PVE is `192.168.11.240`,
hence Media/PBS is `192.168.11.243`.

Source: `vars/core-resource-standard.yml`. The guard
`tasks/core-resource-standard-assert.yml` verifies the bootstrap site
identity, CORE octet allocation and both ID formulas before CORE
№30/№40/№50/№71 actions. It does not change any guest.

## Media Server naming

Canonical CORE **PVE VM name** is `mediaserver-dh-core`:
`mediaserver-` + CORE Site ID. CORE №30 checks the PVE `ipconfig0`
address ends in `.243` and matches the computed VMID2243. It
reports `CORE_MEDIA30_VM_NAME_STANDARD=CANONICAL` when the canonical
name is observed.

During the **pre-Recreate** transition, the existing VM2243 may still
be named `mediaserver-serzhan`. CORE №30 and CORE №40 accept that
specific historical name only as `LEGACY_RECREATE_PENDING` while still
requiring the exact CORE VMID and IP. This is a compatibility exception,
**not** the desired name for new builds.

## Preserved existing data

The physical ZFS pool `serzhan-pool` is independent of the Proxmox
VM name. **Target CORE PBS datastore is only `pbs-core`**; the
`pbs-serzhan` datastore belongs to HOME PBS VM2223, not CORE VM2243.
**Resolved on 16 November 2026 (CORE #40 Job #134):** CORE PBS now registers
only `pbs-core`, and the active 02:00 CORE PVE backup job is
`dh-core-pbs-daily` targeting `pbs-core/dh-core`, still excluding VM2243.
The previous CORE `pbs-serzhan` registration and PVE Storage were removed,
**without deleting** the historical `serzhan-pool/pbs-serzhan` ZFS dataset
(318 GiB). CORE #40/#50 read-only Jobs #135/#136 passed after cutover.

**Recreate + Import belongs only to CORE №31 `apply`**, never to the
read-only CORE №30 E2E or №40 infrastructure tasks. Before that
phase, audit the physical passed-through disk and ZFS pool, independent
backups of guest OS/application state and PBS credentials, and a safe
restore path. Recreate must never use `erase` when preserving the
existing pool. Update live PVE/guest naming only within that explicitly
authorized lifecycle operation. Do not rerun bootstrap on a live CORE.
