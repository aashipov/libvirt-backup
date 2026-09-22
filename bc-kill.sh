#!/bin/sh

# ------------------------------------------------------------
#  bc-kill.sh – Stop running libvirt VM backups
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
    # Load library
    # shellcheck source=lib.sh
    if ! . "${BASE_DIR}/lib.sh"
    then
        printf 'Could not load lib.sh, exiting'
        exit 1
    fi

    # Do the job
    environment
    kill_backup_jobs
    rm_running
}

closure
