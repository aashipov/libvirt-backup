#!/bin/sh

# ------------------------------------------------------------
#  testbed-builder.sh – Headful VM prototype generator
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

remove_vm() {
    if virsh list --all | grep -q "\b${TARGET_VM_NAME}\b"
    then
        if virsh list --name --state-running | grep -q "${TARGET_VM_NAME}"
        then
            virsh destroy "${TARGET_VM_NAME}" || die "Failed to destroy ${TARGET_VM_NAME}"
        fi
        while virsh list --name --state-running | grep -q "\b${TARGET_VM_NAME}\b"
        do
            echo "${TARGET_VM_NAME} is still running. Waiting..."
            sleep 5
        done
        echo "${TARGET_VM_NAME} has shut down."
        virsh undefine "${TARGET_VM_NAME}" || die "Failed to undefine ${TARGET_VM_NAME}"
        rm -rf "${TARGET_DISK_FILE}"
    fi
}

build_disk() {
    if [ ! -f "${TARGET_DISK_FILE}" ]
    then
        qemu-img convert -O qcow2 -o compression_type=zstd -c "${TGT_FILE}" "${TARGET_DISK_FILE}" || die "Failed to convert ${TGT_FILE} to ${TARGET_DISK_FILE}"
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
    # shellcheck source=lib.sh
    if ! . "${BASE_DIR}/lib.sh"
    then
        printf 'Could not load lib.sh, exiting'
        exit 1
    fi

    # Do the job
    environment
    create_backup_dirs_and_log || die "Failed to create_backup_dirs_and_log"

    DISTRO=debian
    SRC_URL="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
    [ -n "${1}" ] && DISTRO="${1}"
    case "${DISTRO}" in
        debian) ;;
        [[:upper:]]*) die "Distro name, lowercase" ;;
        alma)
           SRC_URL="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-ext4-latest.x86_64.qcow2"
           ;;
        ubuntu)
            SRC_URL="https://cloud-images.ubuntu.com/releases/jammy/release/ubuntu-22.04-server-cloudimg-amd64.img"
            SRC_URL="https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-amd64.img"
            ;;
        redos)
            SRC_URL="https://github.com/aashipov/libvirt-backup/releases/download/store/redos-8-20260716.0-x86_64-post-cloud-init.qcow2"
            ;;
        astra)
            SRC_URL="https://registry.astralinux.ru/artifactory/mg-generic/alse/cloudinit/alse-1.7.11-base-cloudinit-mg16.5.0-amd64.qcow2"
            SRC_URL="https://registry.astralinux.ru/artifactory/mg-generic/alse/cloudinit/alse-1.8.6-base-cloudinit-mg16.5.0-amd64.qcow2"
            ;;
           *) die "Distro ${DISTRO} is not supported at the moment" ;;
    esac

    TARGET_VM_NAME="${DISTRO}-builder"
    TARGET_DISK_FILE="${BACKUP_DIR}/${DISTRO}-builder.qcow2"
    TGT_FILE="${BACKUP_DIR}/$(basename "${SRC_URL}")"

    [ ! -e "${TGT_FILE}" ] && curl -L -o "${TGT_FILE}" "${SRC_URL}"
    
    remove_vm
    build_disk

    CLOUD_INIT_ARGS=""
    [ "${DISTRO}" != "redos" ] && CLOUD_INIT_ARGS="--cloud-init meta-data="${BASE_DIR}"/testbed-builder/cloud-init/meta-data,user-data="${BASE_DIR}"/testbed-builder/cloud-init/user-data"
    virt-install --name "${TARGET_VM_NAME}" --memory 4096 --vcpus "$(cpu_count)" --cpu host-passthrough --disk path="${TARGET_DISK_FILE}",format=qcow2,bus=virtio --network network=default,model=virtio --graphics vnc,listen=0.0.0.0 --osinfo detect=on,require=off --import --noautoconsole \
    ${CLOUD_INIT_ARGS}

    SRC_URL="https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/cloud/generic_alpine-3.24.1-x86_64-bios-tiny-r0.qcow2"
    TGT_FILE="${BACKUP_DIR}/$(basename "${SRC_URL}")"
    [ ! -e "${TGT_FILE}" ] && curl -L -o "${TGT_FILE}" "${SRC_URL}"

    printf '%s\n' "Check progress: \`virsh console ${TARGET_VM_NAME}\` or \`virt-manager --connect qemu:///system --show-domain-console ${TARGET_VM_NAME}\` or follow logs via SSH: \`sudo cat /var/log/cloud-init-output.log | tail\`"
    printf '%s\n' "Once it's done, proceed with \`testbed-configurator.sh\`: \`cd ${BASE_DIR} && virsh shutdown ${TARGET_VM_NAME} && sleep 30s && virt-copy-in -d ${TARGET_VM_NAME} testbed-configurator.sh /home/administrator/ && virt-copy-in -d ${TARGET_VM_NAME} ${TGT_FILE} /home/administrator/ && virsh start ${TARGET_VM_NAME} && virsh console ${TARGET_VM_NAME}\`, authenticate & launch \`"./testbed-configurator.sh"\`"

    unset BASE_DIR DISTRO TARGET_VM_NAME TARGET_DISK_FILE SEED_ISO_FILE SRC_URL TGT_FILE CLOUD_INIT_ARGS
}

closure "${@}"
