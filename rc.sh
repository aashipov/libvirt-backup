#!/bin/bash

# ------------------------------------------------------------
#  rc.sh – Push VM backups to ${ANOTHER_SERVER_IP} via rsync and clean local obsolete backups
# ------------------------------------------------------------
# SEE ALSO:
#   ./lib.sh
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
    create_backup_dir
    check_running
    push_backups_to_another_server
    clean_obsolete_backups
}

closure
