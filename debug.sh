#!/bin/sh

# ------------------------------------------------------------
#  debug.sh – debug scripts, e.g. non-interactive shell like cron
# ------------------------------------------------------------

# ./debug.sh | tee "$HOME/libvirt-backup-debug.log"

# ------------------------------------------------------------
#  Main function to prevent occasional environment pollution
# ------------------------------------------------------------
closure() {
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

    set -x # debug

    # Fail loudly (non-zero exit) when virsh is missing or libvirtd is down,
    # so a cron run does not silently "succeed" with nothing dumped.
    virsh version >/dev/null 2>&1 || die "Cannot reach libvirt (is libvirtd running?)"

    log "Environment"
    log "------------------------------------------------------------"
    env
    printf "\n"

    log "User groups"
    log "------------------------------------------------------------"
    groups
    printf "\n"

    local RUNNING_VMS=$(virsh list --name --state-running) || die "Failed to list running VMs"
    for RUNNING_VM in ${RUNNING_VMS}
    do
        printf 'VM: %s\n' "${RUNNING_VM}"
        local DISKS=$(get_vm_disk_names_and_absolute_paths "${RUNNING_VM}") || die "Could not get disk list for ${RUNNING_VM}"
        for DISK in ${DISKS}
        do
            printf "\t%s\n" "${DISK}"
        done
    done
}

closure
