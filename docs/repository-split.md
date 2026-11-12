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
