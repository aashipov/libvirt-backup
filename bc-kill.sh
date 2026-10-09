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
    LIB_SH="${BASE_DIR}/lib.sh"
    if [ ! -e "${LIB_SH}" ]
    then
        printf "${LIB_SH} does not exist, exiting\n"
        exit 1
    fi
    # shellcheck source=lib.sh
    if ! . "${LIB_SH}"
    then
        printf "Could not load ${LIB_SH}, exiting\n"
        exit 1
    fi
    unset LIB_SH

    # Do the job
    environment
    kill_backup_jobs
    rm_running
}

closure
