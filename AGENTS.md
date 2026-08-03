# libvirt VMs live backup

Refer to [README.md](./README.md) for human-facing project setup & usage.

## Project structure

| Path                                         | Role                                                                                                                          |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `bc.sh`                                      | Backup coordinator — sequential, blocking live backups via `virsh backup-begin` (for running VMs) an `cp` (for shut off ones) |
| `bc-kill.sh`                                 | Abort running libvirt backup jobs (`virsh domjobabort`) and remove lock                                                       |
| `rc.sh`                                      | Rsync backups to remote host, clean obsolete local backups                                                                    |
| `lib.sh`                                     | Shared library — env loading, lock/marker, backup logic, push, cleanup, security                                              |
| `weston-runner`                              | Start a Weston RDP session on port 3390 for headful VM management                                                             |
| `.env.template`                              | Single source of truth for mandatory env vars (parsed by `check_mandatory_variables_set`)                                     |
| `.env`                                       | Per-host configuration (gitignored)                                                                                           |
| `HEADFUL.md`                                 | Headful Linux VM prototype guide (Debian + virt-manager + xrdp+Openbox/Weston)                                                |
| `TEST.md`                                    | Manual integration test procedure with nested virtualization                                                                  |
| `.github/workflows/release-with-version.yml` | CI: release tarball with `VERSION.txt`                                                                                        |

## Conventions

- **closure pattern**: every entry-point script wraps its logic in a `closure()` function (not `main`) to isolate the environment.
- **No root** / **No sudo/doas ** : `block_root()` checks `id -u` at startup; `sudo` and `doas` are overridden to abort.
- **Lock file**: `$BACKUP_DIR/$RUNNING_FILE_NAME` prevents concurrent `bc.sh` runs.
- **`.env.template` is the schema**: `check_mandatory_variables_set` greps variable names from it and ensures each is set and non-blank; matched vars are then marked `readonly`.
- **Offline VMs**: disks are `cp -p`'d; **running VMs** use libvirt's push-based backup (`virsh backup-begin` + polling `virsh domjobinfo`).
- **Kill sequence** (manual): `pkill -x bc.sh ; ./bc-kill.sh`
- **Output & logs**: no need it log levels, prefer `printf` over `echo`
