#!/bin/sh

# ------------------------------------------------------------
#  debug.sh – debug scripts, e.g. non-interactive shell like cron
# ------------------------------------------------------------
# The intended use:
# ./debug.sh | tee "$HOME/libvirt-backup-debug.log"

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
    BASE_DIR="$(get_base_dir)"

    # Load library
    . "${BASE_DIR}/lib.sh"

    # Do the job
    cd "${BASE_DIR}"
    environment
    check_running

    #set -x # debug

    printf '%s\n' "Environment"
    printf '%s\n' "------------------------------------------------------------"
    env
    printf "\n"

    printf '%s\n' "User groups"
    printf '%s\n' "------------------------------------------------------------"
    groups
    printf "\n"

    RUNNING_VMS=""
    RUNNING_VMS="$(virsh list --name --state-running)" || fail_internal "Failed to list running VMs"
    for RUNNING_VM in ${RUNNING_VMS}
    do
        printf 'VM: %s\n' "${RUNNING_VM}"
        DISKS=""
        DISKS="$(get_vm_disk_names_and_absolute_paths "${RUNNING_VM}")" || fail_internal "Could not get disk list for ${RUNNING_VM}"
        for DISK in ${DISKS}
        do
            printf "\t%s\n" "${DISK}"
        done
        unset DISKS
    done
    unset BASE_DIR RUNNING_VMS
}

closure
