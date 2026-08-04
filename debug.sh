#!/bin/sh

# ------------------------------------------------------------
#  debug.sh – debug scripts, e.g. non-interactive shell like cron
# ------------------------------------------------------------

# The intended use
# ./debug.sh | tee "$HOME/libvirt-backup-debug.log"

_fail() {
    printf '%s\n' "${@}"
    exit 1
}

# ------------------------------------------------------------
#  Main function to prevent occasional environment pollution
# ------------------------------------------------------------
closure() {
    # Load library
    local _SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$0")")
    local _LIB_SH_FILE="${_SCRIPT_DIR}/lib.sh"
    if [ ! -f "${_LIB_SH_FILE}" ]
    then
        _fail "${_LIB_SH_FILE} is missing. Exiting"
        exit 1
    fi
    . "${_LIB_SH_FILE}"

    # Do the job
    environment

    set -x # debug

    virsh version >/dev/null 2>&1 || _fail "Cannot reach libvirt (is libvirtd running?)"

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
