# CORE bootstrap

Fresh dh-core Proxmox installation ONLY. Expects PVE .240, creates
Semaphore runner CT1241 at .241 and site ID dh-core. This script
refuses an existing guest; it never deletes existing guests or disks.

Run as PVE root:

    bash <(curl -fsSL https://raw.githubusercontent.com/DigitalHouses/Ansible-CORE/main/bootstrap/install.sh)

Repository: DigitalHouses/Ansible-CORE, branch main.
Catalog: catalog/tasks.yml. Runner checkout: /opt/ansible-core.

DO NOT rerun bootstrap on an existing CORE Semaphore installation.
Follow docs/repository-split.md for Git cutover.
