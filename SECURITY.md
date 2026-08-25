# Security

## Supported versions

Only the latest [release](https://github.com/aashipov/libvirt-backup/releases) (or `master`) receives fixes.

## Reporting a vulnerability

Do **not** open a public issue for a vulnerability.

- Report privately via GitHub: repository → *Security* tab → *Report a vulnerability*
- Include: affected version/commit, reproduction steps, impact assessment

You will get an initial response within a few days. Please keep reports confidential until a fix is released.

## What is in scope

- `bc.sh`, `rc.sh`, `lib.sh`, `debug.sh`, `test-runner.sh`, `weston-runner`
- Command injection through `.env` variables, VM names or disk paths
- Lock file / marker handling (`${BACKUP_DIR}/running`)

## Out of scope

- Misconfigured `.env` permissions on your host or a [headful testbed](./HEADFUL.md)
- libvirt/QEMU/rsync vulnerabilities — report upstream
- Attacks requiring local shell access as the running user (the tool deliberately runs unprivileged)
