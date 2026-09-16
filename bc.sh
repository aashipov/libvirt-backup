#!/bin/sh

# ------------------------------------------------------------
#  bc.sh – Live‑disk backup for libvirt VMs
# ------------------------------------------------------------
#
#  Configuration (via .env):
#    BACKUP_DIR          – local directory for backups
#    BACKUP_LOG_FILE     – file to append log messages
#    VM_NAMES_TO_BACK_UP – space separated list of VM names
# ------------------------------------------------------------
# SEE ALSO:
#   https://libvirt.org/kbase/live_full_disk_backup.html
#   ./lib.sh
#   ./bc-kill.sh
#

# ------------------------------------------------------------
# Script/base dir
# ------------------------------------------------------------
get_base_dir() {
    if [ -f "${0}" ]
    then
        # $0 points to a file on disk
        printf '%s\n' "$(cd -- "$(dirname -- "${0}")" && pwd)"
    else
        # The script was sourced in a shell where $0 is not the script path
        # Fallback to the current working directory
        printf '%s\n' "$(pwd)"
    fi
}

# ------------------------------------------------------------
#  Main function to prevent occasional environment pollution
# ------------------------------------------------------------
closure() {
    #set -x # debug

    BASE_DIR="$(get_base_dir)"

    # Load library
    . "${BASE_DIR}/lib.sh"

    # Do the job
    environment

    # Cleanup on interrupt
    trap cleanup_on_exit INT TERM
    # Release the lock on normal exit
    trap rm_running EXIT

    create_backup_dirs_and_log # at this point log file must be available

    check_running
    create_running

    create_current_backup_dir
    clean_obsolete_backups
    export_vm_and_disk_configuration
    check_available_disk_space
    backup_vms
    validate_backups
}

closure
