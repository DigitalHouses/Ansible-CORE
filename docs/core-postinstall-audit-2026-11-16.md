# CORE Media/PBS post-install audit — 2026-11-16

Scope: **dh-core only**. No HOME host, repository, backup job or credentials changed.
Baseline: `DigitalHouses/Ansible-CORE` main `c2611c1`, CORE Semaphore project 1.

## Observed acceptance

| CORE job | Action | Result |
| --- | --- | --- |
| #122 / №31 | Fresh Debian 13 VM2243, original ZFS import, native Media/PBS installation | PASS; guest and PVE acceptance, `failed=0` |
| #123 / №50 | Central PBS audit immediately after rebuild | PASS; `changed=0` |
| #124 / №71 | Tailscale package update PVE/PBS | PASS; both Running |
| #125 / №30 | Read-only Media E2E | PASS; `changed=0`, canonical VM2243/`.243`, NoCloud/TLS/nginx, 12 portal links and 12 services HTTP 200, SMB 445, rclone unauthorized 401 |
| #126 / №40 | Read-only infrastructure and legacy storage audit | EXECUTION PASS; `changed=0`; **ARCHITECTURE DRIFT**: `pbs-serzhan` is wrongly registered on CORE and used by an enabled scheduled backup job |
| #127 / №31 | Read-only VM lifecycle audit | PASS; canonical `mediaserver-dh-core`, running, `changed=0` |
| #128 / №50 | Native PBS namespace Verify | PASS; 21 manifests in `pbs-core/serzhan-home`, worker status `OK`, no schedule; `changed=1` for manual verify execution |
| #129 / №71 | Read-only Tailscale audit on PVE + PBS | PASS; `changed=0`, Tailscale 1.104.7, DNS/default route unchanged, WARP inactive on PBS |

Additional readback: Plex `http://192.168.11.243:32400/identity` reports `claimed="1"`.
Six Ansible contract/render playbooks under `tests/` passed on DEV (local execution; render test uses disposable temporary files).

## Completed CORE-only PBS topology cutover (16 Nov 2026)

CORE #40 Job **#134** succeeded. PVE storage `pbs-core` points to
`192.168.11.243`, datastore `pbs-core`, namespace `dh-core`; its enabled
02:00 backup job is `dh-core-pbs-daily` (`all=1`, `exclude=2243`).
A real CT1241 backup produced the manifest
`pbs-core/ns/dh-core/ct/1241/2026-11-16T13:28:34Z/index.json.blob`.
CORE PVE storage and PBS registration named `pbs-serzhan` no longer exist.
The physical dataset `serzhan-pool/pbs-serzhan` retains **318 GiB**
of historical archives, with no deletion or formatting. HOME unchanged.
CORE #40 Job **#135** returned `COMPLIANT_ONLY_PBS_CORE`, `changed=0`;
CORE #50 Job **#136** read-only audit succeeded, `changed=0`.

## Historical drift before CORE #40 Job #134 (resolved)

- CORE PVE `192.168.11.240`; Semaphore CT1241 `192.168.11.241`; Media/PBS VM2243 `192.168.11.243`.
- **Target:** only PBS datastore `pbs-core` is registered on CORE; `pbs-serzhan` belongs exclusively to HOME PBS VM2223 (`.223`, under HOME PVE `.220`).
- **Observed CORE drift:** PVE storage `pbs-serzhan` points to `.243`; enabled nightly `dh-local-pbs-serzhan` job (02:00, all guests except VM2243) uses it. CORE PBS registers a second, legacy datastore of the same name backed by about **318 GiB** of existing ZFS data. Its prune/verify jobs also exist. This is **not compliant** even though read-only audit execution succeeded.
- At the time of the initial read-only audit, cutover had not been performed. It was subsequently completed in CORE #40 Job #134, preserving the legacy ZFS dataset and snapshots.
- `pbs-core` receives HOME Push Sync in per-home namespaces; no CORE Pull job. A CORE PVE storage mapping is needed only if CORE's own PVE backup job is to use that datastore.
- No VM recreate, disk erase, ZFS mutation, HOME operation or production backup-job change was performed during this audit.

## Not yet fully accepted

1. **Disaster-recovery Restore:** although 21 central snapshots passed native Verify, an actual restore into a separate unused VMID has not been demonstrated. It is a separate E2E action; never overwrite an existing guest.
2. **Central backup lifecycle:** namespace-specific retention/prune, routine Verify/GC scheduling, and snapshot freshness monitoring remain unimplemented. Do not enable deletion policies before Restore E2E and an explicit retention decision.
3. **Client/application end-to-end:** HTTP 200 does not establish Plex playback or GPU hardware transcoding, interactive Media app login, Windows/macOS network-share discovery, or browser noVNC login. Job #122 did validate owner/admin SMB credential login; Plex claim was independently confirmed on 16 November.
4. **HOME recency:** existing 21 manifests prove received backups, not that a newer HOME Push has occurred since the earlier pilot. CORE has not changed HOME.

This audit report records confirmed evidence and explicit remaining limits; it is not a substitute for restore testing.
