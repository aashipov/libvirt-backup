#!/bin/sh

# ------------------------------------------------------------
#  rc.sh – Push VM backups to ${ANOTHER_SERVER_IP} via rsync and clean local obsolete backups
# ------------------------------------------------------------

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

    # Define BASE_DIR
    BASE_DIR="$(get_base_dir)"
    # Load library
    . "${BASE_DIR}/lib.sh"
    [ "${?}" -ne 0 ] && printf 'Could not load lib.sh, exiting' && exit 1

    # Do the job
    environment
    check_rsync
    create_backup_dirs_and_log
    check_running
    clean_obsolete_backups
    push_backups_to_another_server
}

closure
