# CORE: migration of an existing Semaphore

1. Preserve project dh-core, Runner CT1241, inventory, templates, task
   history, credentials and the old Ansible-3 repository record.
2. Add Ansible-CORE main as a second Git repository record.
3. Verify catalog 00 and central PBS 40 and their playbook dependencies.
4. Repoint ONLY owned CORE templates to the new Git repository record.
5. Task 00 creates templates and updates surveys: review before running.
6. Do not run task 40 prepare during repository cutover.
7. Rollback uses the unchanged original Ansible-3 repository.

Original source: b97b840 feat/bootstrap-home-core.

## Live cutover acceptance — 2026-11-12

- Repository `DigitalHouses/Ansible-CORE`, branch `main`, deployed without
  recreating the existing `dh-core / Semaphore — CT1241, 192.168.11.241`.
- Old Ansible-3 repository and Runner inventory remain as backup records.
- The same existing Semaphore project (`dh-core`, project ID 1) and
  templates (`00` ID 1, `40` ID 2), environment, credentials and task history
  are preserved. Both templates now reference CORE repository record ID 2
  and CORE inventory ID 2.
- Live catalog `00` Job #12: success, changed=0, failed=0.
- Live PBS `40` Audit Job #13: success, changed=0, failed=0;
  observed VM2243 at 192.168.11.243. Pull Sync not activated.
- Historical `DigitalHouses/Ansible-3` archived read-only on GitHub.
  Both `main` and `feat/bootstrap-home-core` remain fetchable.

No HOME Semaphore, HOME PVE or HOME Cloudflare resources were changed by
this CORE cutover.
