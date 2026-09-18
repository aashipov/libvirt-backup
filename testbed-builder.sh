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

    # Define BASE_DIR
    BASE_DIR="$(get_base_dir)"
    # Load library
    . "${BASE_DIR}/lib.sh"
    [ "${?}" -ne 0 ] && printf 'Could not load lib.sh, exiting' && exit 1

    # Do the job
    environment
    create_backup_dirs_and_log || die "Failed to create_backup_dirs_and_log"

    DISTRO=debian
    [ ! -z "${1}" ] && DISTRO="${1}"
    [ "${DISTRO}" != "debian" ] && die "Distro ${1} is not supported at the moment"

    TARGET_VM_NAME="${DISTRO}-builder"
    TARGET_DISK_FILE="${BACKUP_DIR}/${DISTRO}-builder.qcow2"
    SEED_ISO_FILE="${BACKUP_DIR}/${DISTRO}"-seed.iso
    GENERIC_IMAGE_URL="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
    GENERIC_IMAGE_FILE="${BACKUP_DIR}/${DISTRO}"-genericcloud.qcow2

    cd "${BASE_DIR}/testbed-builder/${DISTRO}"
    
    if [ ! -f "${SEED_ISO_FILE}" ]
    then
        xorriso -as mkisofs -output "${SEED_ISO_FILE}" -volid cidata -joliet -rock user-data meta-data || die "Failed to create a ${BACKUP_DIR}/${DISTRO}-seed.iso"
    fi

    if [ ! -f "${GENERIC_IMAGE_FILE}" ]
    then
        curl -L -o "${GENERIC_IMAGE_FILE}" "${GENERIC_IMAGE_URL}"
    fi
    
    if virsh list --all | grep -q "${TARGET_VM_NAME}"
    then
        if virsh list --all | grep -q "${TARGET_VM_NAME}" | grep -q "running"
        then
            virsh destroy "${TARGET_VM_NAME}" || die "Failed to destroy ${TARGET_VM_NAME}"
        fi
        virsh undefine "${TARGET_VM_NAME}" || die "Failed to undefine ${TARGET_VM_NAME}"
        rm -rf "${TARGET_DISK_FILE}"
    fi

    if [ ! -f "${TARGET_DISK_FILE}" ]
    then
        qemu-img convert -O qcow2 -o compression_type=zstd -c "${GENERIC_IMAGE_FILE}" "${TARGET_DISK_FILE}" || die "Failed to convert ${GENERIC_IMAGE_FILE} to ${TARGET_DISK_FILE}"
    fi

    virt-install \
      --name "${TARGET_VM_NAME}" \
      --memory 4096 \
      --vcpus 8 \
      --cpu host-passthrough \
      --disk path="${TARGET_DISK_FILE}",format=qcow2,bus=virtio \
      --disk path="${SEED_ISO_FILE}",device=cdrom \
      --network network=default,model=virtio \
      --graphics vnc,listen=0.0.0.0 \
      --os-variant debian13 \
      --boot hd

    unset BASE_DIR DISTRO TARGET_VM_NAME TARGET_DISK_FILE SEED_ISO_FILE GENERIC_IMAGE_URL GENERIC_IMAGE_FILE
}

closure "${@}"
