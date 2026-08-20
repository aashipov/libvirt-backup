#!/bin/sh

# ------------------------------------------------------------
#  bc-kill.sh – Stop running libvirt VM backups
# ------------------------------------------------------------

# ------------------------------------------------------------
#  Main function to prevent occasional environment pollution
# ------------------------------------------------------------
closure() {
    #set -x # debug

    # Load library
    . "$(dirname -- "$(readlink -f -- "$0")")/lib.sh"

    # Do the job
    environment
    kill_backup_jobs
    rm_running
}

closure
