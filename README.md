# libvirt VMs backup

## Setup

Check [HEADFUL.md](./HEADFUL.md), [TEST.md](./TEST.md) for configuration 

With unprivileged user at each host:

- pick archive or clone`git clone https://github.com/aashipov/libvirt-backup.git` or pull recent version `git pull -r`
- make an .env file `cp .env.template .env`, adjust variables (once, per-host variables, especially), fill `VM_NAMES_TO_BACK_UP` in `.env` with VM names to back up
- call `./debug.sh` to check if system is configured correctly
- launch backup jobs `./bc.sh` (consecutive, blocking)
- kill backup jobs `pkill -x bc.sh ; ./bc-kill.sh`
- (optional) adjust `ANOTHER_SERVER_IP` & `ANOTHER_SERVER_USERNAME` in `.env` to reflect the IP and rsync-capable username of 'another' host in the cluster. Run replication & obsolete clean up (`./rc.sh`)

## Details

[Official manual](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/configuring_and_managing_virtualization/backing-up-and-recovering-virtual-machines_configuring-and-managing-virtualization)

[Tools like](https://github.com/abbbi/virtnbdbackup) may not fit an 'air-gapped' / 'airtight' environment / 'secure' linux distros, output disk file is neither raw nor qcow2. GNU Coreutils, sed, grep, environment file and shell script 'glue' might be a simpler alternative

Live/online backup may produce inconsistent data across VMs which depend on each other.

Logical Volume Manager (LVM) is considered slower than traditional partitions. Virtual disks must be attached to VM as virtio / writeback cache mode
