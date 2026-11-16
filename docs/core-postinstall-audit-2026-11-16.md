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
| #126 / №40 | Read-only infrastructure and legacy storage audit | PASS; `changed=0` |
| #127 / №31 | Read-only VM lifecycle audit | PASS; canonical `mediaserver-dh-core`, running, `changed=0` |
| #128 / №50 | Native PBS namespace Verify | PASS; 21 manifests in `pbs-core/serzhan-home`, worker status `OK`, no schedule; `changed=1` for manual verify execution |
| #129 / №71 | Read-only Tailscale audit on PVE + PBS | PASS; `changed=0`, Tailscale 1.104.7, DNS/default route unchanged, WARP inactive on PBS |

Additional readback: Plex `http://192.168.11.243:32400/identity` reports `claimed="1"`.
Six Ansible contract/render playbooks under `tests/` passed on DEV (local execution; render test uses disposable temporary files).

## Retained architecture

- CORE PVE `192.168.11.240`; Semaphore CT1241 `192.168.11.241`; Media/PBS VM2243 `192.168.11.243`.
- `serzhan-pool` and both PBS datastores preserved. Legacy PVE storage `pbs-serzhan` still has real snapshots and is referenced by one PVE backup job `dh-local-pbs-serzhan`: **do not remove or rename**.
- `pbs-core` receives HOME Push Sync in per-home namespaces; no CORE Pull job, no need for PVE storage `pbs-core`.
- No VM recreate, disk erase, ZFS mutation, or HOME operation was performed during this audit.

## Not yet fully accepted

1. **Disaster-recovery Restore:** although 21 central snapshots passed native Verify, an actual restore into a separate unused VMID has not been demonstrated. It is a separate E2E action; never overwrite an existing guest.
2. **Central backup lifecycle:** namespace-specific retention/prune, routine Verify/GC scheduling, and snapshot freshness monitoring remain unimplemented. Do not enable deletion policies before Restore E2E and an explicit retention decision.
3. **Client/application end-to-end:** HTTP 200 does not establish Plex playback or GPU hardware transcoding, interactive Media app login, Windows/macOS network-share discovery, or browser noVNC login. Job #122 did validate owner/admin SMB credential login; Plex claim was independently confirmed on 16 November.
4. **HOME recency:** existing 21 manifests prove received backups, not that a newer HOME Push has occurred since the earlier pilot. CORE has not changed HOME.

This audit report records confirmed evidence and explicit remaining limits; it is not a substitute for restore testing.
