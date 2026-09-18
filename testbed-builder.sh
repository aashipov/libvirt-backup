#!/bin/sh

# ------------------------------------------------------------
#  testbed-builder.sh – Headful VM prototype generator
# ------------------------------------------------------------

# https://dev.to/tjuliu/automating-ubuntu-vm-creation-with-libvirt-kvmqemu-and-cloud-init-2inf
# sudo pacman -S cloud-init cloud-guest-utils libisoburn

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
    set -e
    #set -x # Debug

    DISTRO=debian
    if [ -n "${1}" ]
    then
        DISTRO="${1}"
    fi

    # Define BASE_DIR
    BASE_DIR="$(get_base_dir)"
    # Load library
    . "${BASE_DIR}/lib.sh"
    [ "${?}" -ne 0 ] && printf 'Could not load lib.sh, exiting' && exit 1

    # Do the job
    environment
    create_backup_dirs_and_log || die "Failed to create_backup_dirs_and_log"

    cd "${BASE_DIR}/testbed-builder/${DISTRO}"
    xorriso -as mkisofs -output "${BACKUP_DIR}/${DISTRO}"-seed.iso -volid cidata -joliet -rock user-data meta-data || die "Failed to create a ${BACKUP_DIR}/${DISTRO}-seed.iso"

    unset BASE_DIR DISTRO
}

closure
