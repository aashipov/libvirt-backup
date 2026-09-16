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
- (optional) if you plan to replicate backups to another server/file store via rsync, configure `ANOTHER_SERVER_IP` and establish passwordless SSH connection to it
