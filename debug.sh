#!/bin/sh

# ------------------------------------------------------------
#  debug.sh – debug scripts, e.g. non-interactive shell like cron
# ------------------------------------------------------------
# The intended use:
# ./debug.sh | tee "$HOME/libvirt-backup-debug.log"

# ------------------------------------------------------------
#  Main function to prevent occasional environment pollution
# ------------------------------------------------------------
closure() {
    # Load library
    . "$(dirname -- "$(readlink -f -- "$0")")/lib.sh"

    # Do the job
    check_dot_env_file
    environment

    #set -x # debug

    printf '%s\n' "Environment"
    printf '%s\n' "------------------------------------------------------------"
    env
    printf "\n"

    printf '%s\n' "User groups"
    printf '%s\n' "------------------------------------------------------------"
    groups
    printf "\n"

    local RUNNING_VMS=$(virsh list --name --state-running) || _fail "Failed to list running VMs"
    for RUNNING_VM in ${RUNNING_VMS}
    do
        printf 'VM: %s\n' "${RUNNING_VM}"
        local DISKS=$(get_vm_disk_names_and_absolute_paths "${RUNNING_VM}") || _fail "Could not get disk list for ${RUNNING_VM}"
        for DISK in ${DISKS}
        do
            printf "\t%s\n" "${DISK}"
        done
    done
}

closure
