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

## CORE Proxmox guest display names

Every **new** CORE guest has the literal suffix `-CORE` (uppercase).
The site ID `dh-core`, VMID/CTID, addresses, PBS namespaces and application
identities remain unchanged.

| Guest | ID | Canonical Proxmox label |
| --- | ---: | --- |
| Ansible / Semaphore | CT1241 | `ansible-CORE` |
| Home Assistant | VM2242 | `haos-CORE` |
| Media / PBS | VM2243 | `mediaserver-CORE` |
| PostgreSQL | CT1244 | `postgresql-CORE` |

The **OS hostname inside Media VM2243 stays `mediaserver-dh-core`**:
cloud-init metadata uses a separate `os_hostname` field, never the display
label. The original Proxmox labels `mediaserver-dh-core` and
`mediaserver-serzhan` remain read-only accepted legacy identities so
existing VM2243 can be checked without a recreate. CORE №30 `sync-name`
changes only its PVE display name in place after ownership and IP checks.
For new deployments, №31 creates VM2243 with `mediaserver-CORE` directly.
For a new Semaphore CT, CORE bootstrap creates `ansible-CORE`; it does
not rename any existing live LXC or alter another site's resources.

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
existing pool. A PVE-only Media display-name correction is supported by №30 `sync-name`;
no VM recreation is necessary. Existing LXC hostnames must not be renamed
as a side effect of this policy. Do not rerun bootstrap on a live CORE.
