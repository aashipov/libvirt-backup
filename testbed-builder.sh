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

build_seed_iso_file() {
    if [ ! -f "${SEED_ISO_FILE}" ]
    then
        xorriso -as mkisofs -output "${SEED_ISO_FILE}" -volid cidata -joliet -rock "${BASE_DIR}/testbed-builder/${DISTRO}/user-data" "${BASE_DIR}/testbed-builder/${DISTRO}/meta-data" || die "Failed to create a ${BACKUP_DIR}/${DISTRO}-seed.iso"
    fi
}

download_qcow2() {
    if [ ! -f "${QCOW2_FILE}" ]
    then
        curl -L -o "${QCOW2_FILE}" "${QCOW2_URL}"
    fi
}

remove_vm() {
    if virsh list --all | grep -q "${TARGET_VM_NAME}"
    then
        if virsh list --all | grep -q "${TARGET_VM_NAME}" | grep -q "running"
        then
            virsh destroy "${TARGET_VM_NAME}" || die "Failed to destroy ${TARGET_VM_NAME}"
        fi
        virsh undefine "${TARGET_VM_NAME}" || die "Failed to undefine ${TARGET_VM_NAME}"
        rm -rf "${TARGET_DISK_FILE}"
    fi
}

build_disk() {
    if [ ! -f "${TARGET_DISK_FILE}" ]
    then
        qemu-img convert -O qcow2 -o compression_type=zstd -c "${QCOW2_FILE}" "${TARGET_DISK_FILE}" || die "Failed to convert ${QCOW2_FILE} to ${TARGET_DISK_FILE}"
        qemu-img resize "${TARGET_DISK_FILE}" 10G
    fi
}

cpu_count() {
    CPU_COUNT=1
    CPU_COUNT=$(($(getconf _NPROCESSORS_ONLN) + 0))
    printf '%d\n' ${CPU_COUNT}
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
    QCOW2_URL="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
    [ ! -z "${1}" ] && DISTRO="${1}"
    case "${DISTRO}" in
        debian) ;;
        [[:upper:]]*) die "Distro name, lowercase" ;;
        alma)
           QCOW2_URL="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
           ;;
           *) die "Distro ${DISTRO} is not supported at the moment" ;;
    esac

    TARGET_VM_NAME="${DISTRO}-builder"
    TARGET_DISK_FILE="${BACKUP_DIR}/${DISTRO}-builder.qcow2"
    SEED_ISO_FILE="${BACKUP_DIR}/${DISTRO}"-seed.iso
    QCOW2_FILE="${BACKUP_DIR}/$(basename "${QCOW2_URL}")"

    download_qcow2
    remove_vm
    build_disk

    #build_seed_iso_file

    virt-install \
      --name "${TARGET_VM_NAME}" \
      --memory 4096 \
      --vcpus "$(cpu_count)" \
      --cpu host-passthrough \
      --disk path="${TARGET_DISK_FILE}",format=qcow2,bus=virtio \
      --network network=default,model=virtio \
      --graphics vnc,listen=0.0.0.0 \
      --osinfo detect=on,require=off \
      --import \
      --noautoconsole \
      --cloud-init meta-data=${BASE_DIR}/testbed-builder/${DISTRO}/meta-data,user-data=${BASE_DIR}/testbed-builder/${DISTRO}/user-data
      #--disk path="${SEED_ISO_FILE}",device=cdrom

      printf '%s\n' "Check progress: \`virsh console ${DISTRO}-builder\` or follow logs via SSH: \`sudo cat /var/log/cloud-init-output.log | tail\`"
      printf '%s\n' "Once it's done, turn the guest off: \`virsh shutdown ${DISTRO}-builder\` and proceed with \`testbed-configurator.sh\`"

    unset BASE_DIR DISTRO TARGET_VM_NAME TARGET_DISK_FILE SEED_ISO_FILE QCOW2_URL QCOW2_FILE
}

closure "${@}"
