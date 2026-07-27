#!/bin/bash

# ------------------------------------------------------------
#  bc.sh – Live‑disk backup for libvirt VMs
# ------------------------------------------------------------
#  Requires:
#    - libvirt ≥ 7.2.0
#    - QEMU ≥ 4.2
#    - sh (POSIX‑compliant shell)
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
    local _SCRIPT_DIR=`dirname -- $(readlink -f -- "$0") | cd | pwd`
    local _LIB_SH_FILE=${_SCRIPT_DIR}/lib.sh
    if [ ! -f ${_LIB_SH_FILE} ]
    then
        printf "${_LIB_SH_FILE} is missing. Exiting"
        exit 1
    fi
    . ${_LIB_SH_FILE}

    # Do the job
    environment
    create_backup_dir # at this point log file must be available

    local LAUNCH_DATE=`date +%Y-%m-%d`
    local CURRENT_BACKUP_DIR=${BACKUP_DIR}/${LAUNCH_DATE}

    check_running
    create_current_backup_dir

    create_running
    backup_vms
    rm_running
}

closure
