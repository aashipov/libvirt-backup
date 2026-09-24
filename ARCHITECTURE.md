# Architecture Overview

`libvirt-backup` is a POSIX-compliant shell utility designed to create of QEMU/KVM virtual machine disks and their corresponding configuration metadata (XML files). 

## Core Objectives

- **Zero Downtime:** Backups are performed on live, running domains without interrupting guest services by using temporary external overlays and block consolidation.
- **Self-Contained Backups:** Each backup artifact includes both the raw/qcow2 disk images and the configuration XML required for a single-click restore on a bare-metal host.
- **Maximum Portability:** Written strictly in standard POSIX Shell to eliminate external heavy runtime dependencies (like Python or Go) and ensure smooth operation on lightweight host hypervisors.

## Conventions

- **closure pattern**: every entry-point script wraps its logic in a `closure()` function (not `main`) to isolate the environment.
- **No root** / **No sudo/doas ** : `block_root()` checks `id -u` at startup; `sudo` and `doas` are overridden to abort (except `testbed-configurator.sh`).
- **Lock file**: `${BACKUP_DIR}/running` prevents concurrent `bc.sh` runs. "Stale lock" would complicate things without bringing much value.
- **`.env.template` is the schema**: `check_mandatory_variables_set` greps variable names from it and ensures each is set and non-blank.
- **Offline VMs**: disks are `qemu-img convert`'ed with (`QEMU_IMG_CONVERT_WITH_COMPRESSION=1`) or without (`QEMU_IMG_CONVERT_WITH_COMPRESSION=0`) compression;
- **running VMs** use libvirt's push-based backup (`virsh backup-begin` + polling `virsh domjobinfo`), `QEMU_IMG_CONVERT_WITH_COMPRESSION=1` will produce a `*.qcow2-shrunk` images (same `qemu-img convert -O qcow2 -c <src> <tgt>`).
- for now we skip **paused/suspended** VMs
- **Kill sequence** (manual): `pkill -x bc.sh ; ./bc-kill.sh`
- **Output & logs**: no need in log levels, prefer `printf` over `echo`
- Do not suggest **CI improvements** (GitHub Actions do not play well with QEMU/KVM, dedicated public testbed will add running cost)
- `TOCTOU race on lock file` is not an issue
- `debug.sh leaks the full environment` is not an issue (no secrets to store)
- [POSIX.1-2024](https://pubs.opengroup.org/onlinepubs/9799919799/) conformance

## Workflow

The larger the VM's disk, the more data is on it, the longer backup will take. For hundreds of GiB a disk it takes up to a half a day with modern enterprise-grade hardware.

Preflight configuration check (`dry-run`) `./debug.sh` (once per configuration round)

Main script `bc.sh` - backup coordinator — sequential, blocking live backups via `virsh backup-begin` (for running VMs) or `qemu-img convert ...` (for shut off ones)

Kill sequence for a running backup job `pkill -x bc.sh ; ./bc-kill.sh`

(Optional) `./rc.sh` - replication & obsolete clean up coordinator

## Design notes

[Official manual](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/configuring_and_managing_virtualization/backing-up-and-recovering-virtual-machines_configuring-and-managing-virtualization)

[Tools like](https://github.com/abbbi/virtnbdbackup) may not fit an 'air-gapped' / 'airtight' environment / 'secure' linux distros, output disk file is neither raw nor qcow2, hence restore procedure will require a lot more than a file copy

Enterprise solutions like [Proxmox Backup Server](git://git.proxmox.com/git/proxmox-backup.git) are convoluted

[Bindings](https://gitlab.com/libvirt) for popular programming languages do exist. Those imply compilation, virtual machine overhead or both, which complicates release cadence

POSIX Shell Command Language, grep, awk, an environment file make a simpler alternative to the above

## Limitations

- whitespace is **NOT** allowed in directory/file names or VM names
- VM disks must have unique file names
- every copy is a qcow2 (space-efficient)
- only `file`-backed disks are supported — the source must be a local file
- paused/suspended VMs are skipped; any other non-running state (e.g. `crashed`, `in shutdown`) is treated as an offline backup and its disks are copied as-is, so the image may be inconsistent
- `live` / `online` backup may produce inconsistent data across VMs which depend on each other. For consistency, go for 'offline' backup (turn VMs off).
- `simultaneous` backup of multiple VMs will overwhelm the system
- logical Volume Manager (LVM) is considered slower than traditional partitions
- virtual disks must be attached to VM as virtio / writeback cache mode
