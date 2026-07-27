# libvirt VMs live backup

Refer to [README.md](./README.md) for human-facing project details.

This document provides a detailed technical overview of a shell script collection to back `libvirt` Virtual Machines up and syncronize backups across cluster members.

## 1. Architecture & Structure

This tool is composed of the following main components:

- `.env`: per-host environment variables
- `.env.template`: example for the above
- `lib.sh`: shared functions
- `bc.sh`: launch backup.
- `bc-kill.sh`: kill running backup jobs
- `rc.sh`: syncronize backups across cluster and clean obsolete backups

## 2. Dependencies & Setup

- libvirt ≥ 7.2.0
- QEMU ≥ 4.2
- modern POSIX‑compliant shell
- unprivileged user with `virsh` clearance (as per Distro manual)

Per-host configuration via `.env` file, git is recommended (archived is also possible)
