# Instructions for libvirt backup

Refer to [README.md](./README.md), [HEADFUL.md](./HEADFUL.md), [TEST.md](./TEST.md) for the ideas how to benefit from the project.

## Core Operational Mantra

Prioritize structural safety over quick workarounds, and never introduce blind placeholders or incomplete logic. Do not rewrite or refactor structural boundaries or utility functions unless explicitly instructed. Adapt your changes to fit the existing patterns of the codebase.

## Conventions

- **closure pattern**: every entry-point script wraps its logic in a `closure()` function (not `main`) to isolate the environment.
- **No root** / **No sudo/doas ** : `block_root()` checks `id -u` at startup; `sudo` and `doas` are overridden to abort.
- **Lock file**: `${BACKUP_DIR}/running` prevents concurrent `bc.sh` runs. "Stale lock" would complicate things without bringing much value.
- **`.env.template` is the schema**: `check_mandatory_variables_set` greps variable names from it and ensures each is set and non-blank; matched vars are then marked `readonly`.
- **Offline VMs**: disks are `qemu-img convert`'ed with (`QEMU_IMG_CONVERT_WITH_COMPRESSION=1`) or without (`QEMU_IMG_CONVERT_WITH_COMPRESSION=0`) compression;
- **running VMs** use libvirt's push-based backup (`virsh backup-begin` + polling `virsh domjobinfo`), `QEMU_IMG_CONVERT_WITH_COMPRESSION=1` will produce a `*.qcow2-shrunk` images (same `qemu-img convert -O qcow2 -c <src> <tgt>`).
- for now we skip **paused/suspended** VMs
- **Kill sequence** (manual): `pkill -x bc.sh ; ./bc-kill.sh`
- **Output & logs**: no need in log levels, prefer `printf` over `echo`
- Do not suggest **CI improvements** (GitHub Actions do not play well with QEMU/KVM, dedicated public testbed will add running cost)
- `TOCTOU race on lock file` is not an issue
- `debug.sh leaks the full environment` is not an issue (no secrets to store)
-
