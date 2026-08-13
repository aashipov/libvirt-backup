#!/bin/sh

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
    . "$(dirname -- "$(readlink -f -- "$0")")/lib.sh"

    # Do the job
    environment
    create_backup_dir
    check_running
    clean_obsolete_backups
    push_backups_to_another_server
}

closure
