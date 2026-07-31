# libvirt VMs live backup

## Prerequisites

- libvirt ≥ 7.2.0
- QEMU ≥ 4.2
- modern Bash/Dash
- unprivileged user with `virsh` clearance (as per Distro manual)

## Setup

With VMs present on the host `virsh list --all` returns empty list, check `virsh --connect qemu:///system list --all`

Configure on per-host (uncomment `uri_default = "qemu:///system"` in `/etc/libvirt/libvirt.conf`) or per-user basis:

```shell
mkdir -p ${HOME}/.config/libvirt/
cat << 'EOF' | tee -a ${HOME}/.config/libvirt/libvirt.conf
uri_default = "qemu:///system"
EOF
```

With unprivileged user at each host:

- pick archive or clone`git clone https://github.com/aashipov/libvirt-backup.git` or pull recent version `git pull -r`
- make an .env file `cp .env.template .env`, adjust variables (Per-host variables, especially)
- fill `VM_NAMES_TO_BACK_UP` in `.env` file as per:

```shell
cat << EOF | tee -a .env
VM_NAMES_TO_BACK_UP="`virsh list --all | grep running | tr -s ' ' | cut -d ' ' -f 3 | tr '\n' ' '`"
EOF
```
- check if `VM_NAMES_TO_BACK_UP` in `.env` is a complete list of VM to back up
- launch backup jobs `./bc.sh` (consecutive, blocking)
- kill backup jobs `pkill -f bc.sh ; ./bc-kill.sh`
- adjust `ANOTHER_SERVER_IP` & `ANOTHER_SERVER_USERNAME` in `.env` to reflect the IP and rsync-capable username of 'another' host in the cluster
- replicate backups and clean obsoletes `./rc.sh`

## Details

[Official manual](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/configuring_and_managing_virtualization/backing-up-and-recovering-virtual-machines_configuring-and-managing-virtualization)

[Tools like](https://github.com/abbbi/virtnbdbackup) may not fit an 'air-gapped' / 'airtight' environment / 'secure' linux distros, output disk file is neither raw nor qcow2. GNU Coreutils, sed, grep, environment file and shell script 'glue' might be a simpler alternative

Live/online backup may produce inconsistent data across VMs which depend on each other.

Logical Volume Manager (LVM) is considered slower than traditional partitions. Virtual disks must be attached to VM as virtio / writeback cache mode

Online backup will produce a 'shrinkable', often twice as large. Become owner (sudo chown -R `id -u`:`id -g` orig.qcow2) then shrink `qemu-img convert -O qcow2 -c orig.qcow2 shrunk.qcow2`
