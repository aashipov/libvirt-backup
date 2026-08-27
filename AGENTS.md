# Instructions for libvirt backup

Refer to [README.md](./README.md), [HEADFUL.md](./HEADFUL.md), [TEST.md](./TEST.md) for the ideas how to benefit from the project.

## Core Operational Mantra

Prioritize structural safety over quick workarounds, and never introduce blind placeholders or incomplete logic. Do not rewrite or refactor structural boundaries or utility functions unless explicitly instructed. Adapt your changes to fit the existing patterns of the codebase.

## Project structure

| Path                                         | Role                                                                                                                          |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `bc.sh`                                      | Backup coordinator — sequential, blocking live backups via `virsh backup-begin` (for running VMs) an `cp` (for shut off ones) |
| `bc-kill.sh`                                 | Abort running libvirt backup jobs (`virsh domjobabort`) and remove lock                                                       |
| `rc.sh`                                      | Rsync backups to remote host, clean obsolete local backups                                                                    |
| `lib.sh`                                     | Shared library — env loading, lock/marker, backup logic, push, cleanup, security                                              |
| `debug.sh`                                   | to check if system is configured correctly                                                                                    |
| `test-runner.sh`                             | A semi-automated integration [test](./test.sh) runner                                                                         |
| `weston-runner`                              | Start a Weston RDP session on port 3390 for headful VM management                                                             |
| `.env.template`                              | Single source of truth for mandatory env vars (parsed by `check_mandatory_variables_set`)                                     |
| `.env`                                       | Per-host configuration (gitignored)                                                                                           |
| `HEADFUL.md`                                 | Headful Linux VM prototype guide (Debian + virt-manager + xrdp+Openbox/Weston)                                                |
| `TEST.md`                                    | Manual integration test procedure with nested virtualization                                                                  |
| `.github/workflows/release-with-version.yml` | CI: release tarball with `VERSION.txt`                                                                                        |

## Conventions

- **closure pattern**: every entry-point script wraps its logic in a `closure()` function (not `main`) to isolate the environment.
- **No root** / **No sudo/doas ** : `block_root()` checks `id -u` at startup; `sudo` and `doas` are overridden to abort.
- **Lock file**: `${BACKUP_DIR}/running` prevents concurrent `bc.sh` runs. "Stale lock" would complicate things without bringing much value.
- **`.env.template` is the schema**: `check_mandatory_variables_set` greps variable names from it and ensures each is set and non-blank; matched vars are then marked `readonly`.
- **Offline VMs**: disks are `cp`'d (`QEMU_IMG_CONVERT_WITH_COMPRESSION=0`) or `qemu-img convert -O qcow2 -c <src> <tgt>` (`QEMU_IMG_CONVERT_WITH_COMPRESSION=1`);
- **running VMs** use libvirt's push-based backup (`virsh backup-begin` + polling `virsh domjobinfo`), `QEMU_IMG_CONVERT_WITH_COMPRESSION=1` will produce a `*.qcow2-shrunk` images (same `qemu-img convert -O qcow2 -c <src> <tgt>`).
- for now we skip **paused/suspended** VMs
- **Kill sequence** (manual): `pkill -x bc.sh ; ./bc-kill.sh`
- **Output & logs**: no need it log levels, prefer `printf` over `echo`
- Do not suggest **CI improvements** (GitHub Actions do not play well with QEMU/KVM, dedicated public testbed will add running cost)
- `TOCTOU race on lock file` is not an issue
- `debug.sh leaks the full environment` is not an issue (no secrets to store)
- 
