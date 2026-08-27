# libvirt VMs backup

A `cron`-compatible command-line tool to create `QEMU/KVM/libvirt` (compressed) disk images (backups) `one-by-one`

## Provisioning & Setup

QEMU/KVM/libvirt `file`-backed disks tend to grow big, they perform `better` when deployed to `xfs`-formatted block device. For details refer to [HEADFUL.md](./HEADFUL.md).

Check [HEADFUL.md](./HEADFUL.md), [TEST.md](./TEST.md) for configuration cookbook

The project is a collection of shell-scripts, no compilation is required

Typical deployment is to an unprivileged user `${HOME}` directory

With access to the Internet `git clone https://github.com/aashipov/libvirt-backup.git` deployment and `git pull -r` updates are recommended

For 'air-gapped' / 'airtight' environments pick a top [Release libvirt-backup-*.tar.gz](https://github.com/aashipov/libvirt-backup/releases) `libvirt-backup*.tar.gz` asset, extract with overwrite `mkdir -p ${HOME}/libvirt-backup/ && tar --strip-components=1 -xzf libvirt-backup*.tar.gz -C ${HOME}/libvirt-backup/`

Configuration is stored in `.env` file. Craft one from a template `cp .env.template .env`

- store space-separated list of VM you wish to back up to `VM_NAMES_TO_BACK_UP`
- adjust `BACKUP_TIMEOUT_SECONDS` a time limit for `live` backup to complete
- `QEMU_IMG_CONVERT_WITH_COMPRESSION`: 0 do not compress, 1 perform `qemu-img convert -O qcow2 -c ... src tgt` compression (time consuming, but shrinks the backup significantly)
- `MINIMUM_FREE_DISK_SPACE_REQUIRED` preflight free store check
- (optional) if you plan to replicate backups to another server/file store via rsync, configure `ANOTHER_SERVER_IP`, `ANOTHER_SERVER_USERNAME` and establish passwordless SSH connection to it

## Workflow

The larger the VM's disk, the more data is on it, the longer backup will take. For hundreds of GiB a disk it takes up to a half a day with modern enterprise-grade hardware.

Preflight configuration check `./debug.sh` (once per configuration round)

Main script `bc.sh` - backup coordinator — sequential, blocking live backups via `virsh backup-begin` (for running VMs) or `cp` (for shut off ones)

Kill sequence for a running backup job `pkill -x bc.sh ; ./bc-kill.sh`

(Optional) `./rc.sh` - replication & obsolete clean up

## Design notes

[Official manual](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/configuring_and_managing_virtualization/backing-up-and-recovering-virtual-machines_configuring-and-managing-virtualization)

[Tools like](https://github.com/abbbi/virtnbdbackup) may not fit an 'air-gapped' / 'airtight' environment / 'secure' linux distros, output disk file is neither raw nor qcow2, hence restore procedure will require a lot more than a file copy

Enterprise solutions like [Proxmox Backup Server](git://git.proxmox.com/git/proxmox-backup.git) are convoluted

[Bindings](https://gitlab.com/libvirt) for popular programming languages do exist

GNU Coreutils, sed, grep, environment file and shell script 'glue' is a less consuming alternative to the above for a prototype

## Limitations

- whitespace is **NOT** allowed in directory/file names or VM names
- VM disks must have unique file names
- every copy is a qcow2 (space-efficient)
- only `file`-backed disks are supported — the source must be a local file
- paused/suspended VMs are skipped; any other non-running state (e.g. `crashed`, `in shutdown`) is treated as an offline backup and its disks are copied as-is, so the image may be inconsistent
- 'Live' / 'online' backup may produce inconsistent data across VMs which depend on each other. For consistency, turn VMs off, go for 'offline' backup (with/without compression). `Simultaneous` backup of multiple disks will overload system
- Logical Volume Manager (LVM) is considered slower than traditional partitions. Virtual disks must be attached to VM as virtio / writeback cache mode
