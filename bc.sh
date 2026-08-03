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
#  Main function to prevent occasional environment pollution
# ------------------------------------------------------------
closure() {
    #set -x # debug

    # Load library
    local _SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$0")")
    local _LIB_SH_FILE="${_SCRIPT_DIR}/lib.sh"
    if [ ! -f "${_LIB_SH_FILE}" ]
    then
        printf '%s is missing. Exiting\n' "${_LIB_SH_FILE}"
        exit 1
    fi
    . "${_LIB_SH_FILE}"

    # Do the job
    environment
    create_backup_dir # at this point log file must be available

    local LAUNCH_DATE=$(date +%Y-%m-%d)
    local CURRENT_BACKUP_DIR="${BACKUP_DIR}/${LAUNCH_DATE}"

    create_current_backup_dir
    check_running
    
    # Cleanup on interrupt
    trap cleanup_on_exit INT TERM
    # Release the lock on normal exit
    trap rm_running EXIT

    create_running
    backup_vms
    validate_backups
}

closure
