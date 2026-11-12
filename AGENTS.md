# Ansible-CORE developer rules

Only DigitalHouses/Ansible-CORE and central dh-core scope.
Do not run HOME setup, media, HAOS, or HOME Cloudflare tasks from CORE.
Follow ANSIBLE_STANDARDS.md; native Ansible only, no custom Python in roles.
No private manifests or credentials in Git. Do not alter working PBS,
backup jobs, media disks, or VMs during repository cutover.
Verify Semaphore repository and task ownership before any execution.
