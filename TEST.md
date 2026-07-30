# Manual Integration Test

## Prerequisites

The advised setting is `nested virtualization` (a couple of VMs inside a test VM)

Create `debian-prototype.qcow2` as per [HEADFUL.md](./HEADFUL.md)

Create a `test VM` (copy `debian-prototype.qcow2`, attach to it as VirtIO disk)

Deploy `debian-prototype.qcow2` to `test VM` via SSH

The rest of the test case is performed with `test VM`. Use `xrdp` (port 3389) or `weston` `xrdp` (port 3390) RDP servers for GUI

### Once, per-test-VM configuration

'Nested' virtualization fails with Debian (host & guest network address spaces `192.168.122.0/24` clash):
use `sudo virsh net-edit default` to switch `nested` network to `192.168.123.0/24` or alike

Configure networks startup `sudo virsh net-autostart default && sudo virsh net-start default`

Configure userspace libvirt:

```shell
mkdir -p ${HOME}/.config/libvirt/
cat << 'EOF' | tee -a ${HOME}/.config/libvirt/libvirt.conf
uri_default = "qemu:///system"
EOF
```

Create & configure nested VMs called `a` (running) and `b` (shut off)

Create disks:

- make a `debian-prototype.qcow2` copy `sudo cp ~/debian-prototype.qcow2 /var/lib/libvirt/images/a.qcow2`

- create `b.qcow2` as `qemu-img create -f qcow2 b.qcow2 32G && sudo mv b.qcow2 /var/lib/libvirt/images/b.qcow2`

With `virt-manager` create a VM called `a`, attach `debian-prototype.qcow2` copy (`a.qcow2`) to it, then create a `b` machine, attach `b.qcow2` to it.

Check if `virsh list --all` lists machines a & b

With test VM create `/backup-vm/` & `/other_backup/`, assign access rights to unprivileged user (`${USER}`): `sudo mkdir -p /backup-vm/ /other_backup/ && sudo setfacl -d -R -m u:${USER}:rwx /backup-vm/ /other_backup/`

## Per-test-round steps

### 0. Check `a` VM is running

Do `virsh list --all`. VM `a` must be running, if not `virsh start a` and repeat.

## 1. Lint

```sh
./lint.sh
```

Expected: zero errors across all scripts (bash, sh).

### 2. Environment sanity

Deploy source code to test VM

`${HOME}/libvirt-backup/` directory must contain release version of code

```sh
cp .env.template .env
# edit .env:
#   VM_NAMES_TO_BACK_UP  – space-separated list of running VM names
#   ANOTHER_SERVER_IP    – reachable IP
#   ANOTHER_SERVER_USERNAME – user with rsync+SSH key access
#   DAYS_TO_KEEP_BACKUPS – e.g. "+1" for testing (removes dirs older than 1 day)
```

`${HOME}/libvirt-backup/.env` must be present and reflect test VM configuration

Verify `.env` loads without error:

```sh
bash -c 'set -a; source .env; set +a; echo OK'
```

Expected: `OK`.

### 3. Backup (happy path)

```sh
./bc.sh
```

Expected behaviours:
- [ ] Directory `$BACKUP_DIR/YYYY-mm-dd/{a,b}` created
- [ ] Per-VM subdirectories with:
  - `disks.psv` – pipe-separated disk list
  - `VM_NAME.xml` – domain XML dump
  - `VM_NAME-backup-job-descriptor.xml` (running VMs only)
  - `*.qcow2` disk image(s)
- [ ] `$BACKUP_DIR/running` marker file removed after completion
- [ ] Log lines appended to `$BACKUP_DIR/backup.log`
- [ ] Exit code 0

### 4. Idempotency – second backup

Run `./bc.sh` again immediately.

Expected:
- [ ] New `$BACKUP_DIR/YYYY-mm-dd/{a,b}` directory created (same-day re-run)
- [ ] All VM artifacts re-created under the new date dir
- [ ] No stale `$BACKUP_DIR/running` marker
- [ ] Exit code 0

### 5. Lock/marker collision

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

### 6. Missing `.env`

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

### 7. Kill running backup

Start a long-running backup (e.g. a VM with a large disk) and in another terminal:

```sh
pkill -f bc.sh
./bc-kill.sh
```

Expected:
- [ ] `virsh domjobabort` called for each running VM
- [ ] `$BACKUP_DIR/running` marker removed
- [ ] Log lines record each killed job
- [ ] Exit code 0

### 8. Replicate to remote server (rc.sh)

```sh
./rc.sh
```

Expected:
- [ ] `rsync` pushes `$BACKUP_DIR/` to `$ANOTHER_SERVER_USERNAME@$ANOTHER_SERVER_IP:$ANOTHER_SERVER_ANOTHER_BACKUP_DIR/`
- [ ] Local backups older than `$DAYS_TO_KEEP_BACKUPS` are removed
- [ ] Remote backups older than `$DAYS_TO_KEEP_BACKUPS` are removed (if `ANOTHER_SERVER_ANOTHER_BACKUP_DIR` is locally accessible, e.g. NFS mount)
- [ ] Log lines record push start/finish, clean start/finish
- [ ] Exit code 0

### 9. Block root / sudo

```sh
sudo ./bc.sh
```

Expected:
- [ ] Script exits immediately: "Error: This script must not be run as root or with sudo"
- [ ] Same behaviour for `doas ./bc.sh`

### 10. Verify backup integrity

```sh
# For each backed-up VM and each qcow2 disk:
qemu-img check BACKUP_DIR/YYYY-mm-dd/${a,b}/${a,b}.qcow2
qemu-img info BACKUP_DIR/YYYY-mm-dd/${a,b}/${a,b}.qcow2
```

Expected:
- [ ] `qemu-img check` reports "no errors"
- [ ] Virtual size matches original disk

### 11. Clean up test data

```sh
rm -rf "$BACKUP_DIR"
# On remote if applicable:
# ssh $ANOTHER_SERVER_USERNAME@$ANOTHER_SERVER_IP rm -rf "$ANOTHER_SERVER_ANOTHER_BACKUP_DIR"
```

### Test environment

Record the test environment for reproducibility:

| Item | Value |
|---|---|
| Date | |
| Host OS | |
| libvirt version | `virsh --version` |
| QEMU version | `qemu-img --version` |
| Bash version | `bash --version` |
| VM names tested | |
| VM disk types | |
| Remote reachable | |
