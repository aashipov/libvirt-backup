# Instructions for libvirt backup

Refer to [README.md](./README.md), [HEADFUL.md](./HEADFUL.md), [TEST.md](./TEST.md) for the ideas how to benefit from the project.

> [!IMPORTANT]
>
> AI-generated code is allowed. What is **not** allowed is submitting code you do not understand. You are 100% responsible for every line, however it was produced.
>
> [pi](https://github.com/earendil-works/pi) or [opencode](https://github.com/anomalyco/opencode), backed by [llama.cpp](https://github.com/ggml-org/llama.cpp) local models like [Gemma 4](https://huggingface.co/google/gemma-4-E2B-it-qat-q4_0-gguf) or [QWEN 3](https://huggingface.co/Qwen/Qwen3-4B-GGUF), cloud models like DeepSeek V4, will produce a lot of `belles-lettres` / `fluff` / `good intentions` / `Salon Blödsinn`. Check relevance & [TEST.md](./TEST.md) conformance before commiting those.

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
