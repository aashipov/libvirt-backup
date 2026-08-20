# Manual Integration Test

## Prerequisites

The advised setting is `nested virtualization` (a couple of VMs inside a test VM)

Create `debian-prototype.qcow2` as per [HEADFUL.md](./HEADFUL.md)

Create a `test VM` (copy `debian-prototype.qcow2`, attach to it as VirtIO disk). Favor `i440FX` Chipset

Deploy [alpine image](https://alpinelinux.org/cloud/) to `test VM` via SSH (disk for the future `a` VM)

The rest of the test case is performed with `test VM`. Use `xrdp` (port 3389) or `weston` `xrdp` (port 3390) RDP servers for GUI

### Once, per-test-VM configuration

Create & configure nested VMs called `a` (running) and `b` (shut off)

Create a prototype disk:

```sh
qemu-img convert -O qcow2 -c generic_alpine*.qcow2 prototype.qcow2
```

Create future VMs disks out of a prototype:

```sh
for item in a b c; do sudo cp prototype.qcow2 /var/lib/libvirt/images/"$item".qcow2; done
```

Create VMs:

```sh
for item in a b c; do virt-install --name "$item"  --ram 768 --vcpus 2 --disk path=/var/lib/libvirt/images/"$item".qcow2,format=qcow2,bus=virtio --os-variant generic --network network=default --graphics none --import --noautoconsole --noreboot ; done
```

Create a blank prototype disk:

```sh
qemu-img create -f qcow2 blank-prototype.qcow2 256M
```

Create blank prototype disks for VMs a & b:

```sh
for item in a b; do sudo cp blank-prototype.qcow2 /var/lib/libvirt/images/"$item$item".qcow2; done
```

Attach the blank disk to VMs a & b:

```sh
for item in a b; do virsh attach-disk "$item" /var/lib/libvirt/images/"$item$item".qcow2 vdb --driver qemu --subdriver qcow2 --config; done
```

With `virt-manager` VM configuration.

Check if `virsh list --all` lists machines a & b

With test VM create `/backup-vm/` & `/other_backup/`, assign access rights to unprivileged user (`${USER}`):

```sh
sudo mkdir -p /backup-vm/ /other_backup/ && sudo setfacl -d -R -m u:${USER}:rwx /backup-vm/ /other_backup/ && sudo chown -R `id -u`:`id -g` /backup-vm/ /other_backup/
```

Host: create alias `unix` for VM gray IP in `/etc/hosts` or via ssh config

Host: generate SSH key for rsync & access: `mkdir -p ${HOME}/.ssh/unix/ && ssh-keygen -t rsa -b 4096 -C "dummy@dummy.org" -f ${HOME}/.ssh/unix/id_rsa`. Deploy the pair to guest's `${HOME}/.ssh/`.

Host:

```sh
cat << 'EOF' | tee -a ${HOME}/.ssh/config
Host unix
    HostName unix
    User user
    IdentityFile ~/.ssh/unix/id_rsa
    IdentitiesOnly yes
EOF
```

Host:

```sh
ssh-copy-id -i ~/.ssh/unix/id_rsa unix
```

Guest: `ssh-copy-id 127.0.0.2`, verify paswordless login `ssh 127.0.0.2`

## Per-test-round steps

### Check `a` VM is running

Do `virsh list --all`. VM `a` must be running, `c` - paused.

If not `virsh start a ; virsh start c ; virsh suspend c` and repeat `virsh list --all`

### Environment sanity

Deploy source code to test VM

`${HOME}/libvirt-backup/` directory must contain release version of code

```sh
cp .env.template .env
```

`${HOME}/libvirt-backup/.env` must be present and reflect test VM configuration

Verify `.env` loads without error:

```sh
bash -c 'set -a; source .env; set +a; echo OK'
```

Expected: `OK`.

### Backup (happy path)

```sh
./bc.sh
```

Expected behaviours:

- [ ] Directory `$BACKUP_DIR/YYYY-mm-dd/{a,b}/` created
- [ ] Per-VM (`a`, `b`) subdirectories with:
  - `disks.psv` – pipe-separated disk list
  - `VM_NAME.xml` – domain XML dump
  - `VM_NAME-backup-job-descriptor.xml` (running VMs only)
  - `*.qcow2` or `*.qcow2-shrunk` disk image(s)
- [ ] `$BACKUP_DIR/running` marker file removed after completion
- [ ] Log lines appended to `$BACKUP_DIR/backup.log`
- [ ] Exit code 0

### Lock/marker collision

```sh
touch "$BACKUP_DIR/running"
./bc.sh
```

Expected:

- [ ] Script exits with error: "Another copy of this file may be running..."
- [ ] `$BACKUP_DIR/backup.log` contains the error message

```sh
rm "$BACKUP_DIR/running"
```

### Missing `.env`

```sh
mv .env .env.bak
./bc.sh
```

Expected:

- [ ] Script exits with error: "No .env file found"
- [ ] No backup artifacts created

```sh
mv .env.bak .env
```

### Kill running backup

Start a long-running backup (e.g. a VM with a large disk) and in another terminal:

```sh
pkill -x bc.sh ; ./bc-kill.sh
```

Expected:

- [ ] `virsh domjobabort` called for each running VM
- [ ] `$BACKUP_DIR/running` marker removed
- [ ] Log lines record each killed job
- [ ] Exit code 0

### Block root / sudo

```sh
sudo ./bc.sh
```

Expected:

- [ ] Script exits immediately: "Error: This script must not be run as root or with sudo"
- [ ] Same behaviour for `doas ./bc.sh`

### Verify backup integrity

```sh
# For each backed-up VM and each qcow2 disk
find /backup-vm/ -type f -name '*.qcow2*' -exec qemu-img info {} \;
find /backup-vm/ -type f -name '*.qcow2*' -exec qemu-img check {} \;
```

Expected:

- [ ] `qemu-img check` reports "no errors"
- [ ] Virtual size matches original disk

Copy/move `a.qcow2` backup to `/var/lib/libvirt/images/` under `a.qcow2` name, create a VM out of it, check if it runs the way `a` VM does

### Backup timeout

Set `BACKUP_TIMEOUT_SECONDS` to `10` in `.env`

Launch `./bc.sh`, wait for 10 seconds

The process terminates itself, check `Backup job for a did not finish within 10s` message

Verify no `running` file present in the current backup directory

### Rsync

Launch `./rc.sh`, check `/other_backup` contains `/backup-vm` copy

### Cron-managed backup & sync

Clear up test data

Launch cron editor `crontab -e`

Schedule a job to near future, e.g. `59 0 15 * * ${HOME}/libvirt-backup/bc.sh && ${HOME}/libvirt-backup/rc.sh`

Check `/backup-vm/backup.log`, confirm backup created in `/backup-vm/` and copied to `/other_backup/`

### Clean up test data

```sh
rm -rf "${BACKUP_DIR}/*/ ${ANOTHER_SERVER_ANOTHER_BACKUP_DIR}/*/"
```

### Test environment

Record the test environment for reproducibility:

| Item             | Value                |
| ---------------- | -------------------- |
| Date             |                      |
| Host OS          |                      |
| libvirt version  | `virsh --version`    |
| QEMU version     | `qemu-img --version` |
| Bash version     | `bash --version`     |
| VM names tested  |                      |
| VM disk types    |                      |
| Remote reachable |                      |
