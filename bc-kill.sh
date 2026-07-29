#!/bin/bash

# ------------------------------------------------------------
#  bc-kill.sh – Stop running libvirt VM backups
# ------------------------------------------------------------

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
    kill_backup_jobs
    rm_running
}

closure
