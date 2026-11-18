#!/bin/sh

# ------------------------------------------------------------
#  testbed-builder.sh – Headless VM prototype generator by cloud-init URL
# ------------------------------------------------------------

# ------------------------------------------------------------
# Script/base dir
# ------------------------------------------------------------
get_base_dir() {
    if [ -f "${0}" ]
    then
        # $0 points to a file on disk
        printf '%s\n' "$(cd -- "$(dirname -- "${0}")" && pwd -P)"
    else
        # The script was sourced in a shell where $0 is not the script path
        # Fallback to the current working directory
        printf '%s\n' "$(pwd -P)"
    fi
}

# ------------------------------------------------------------
#  Main function to prevent occasional environment pollution
# ------------------------------------------------------------
closure() {
    set -e
    #set -x # debug

    # Define BASE_DIR
    BASE_DIR="$(get_base_dir)"
    # Load libraries
    LIB_NAMES="lib.sh test-lib.sh"
    for LIB_NAME in ${LIB_NAMES}
    do
        if [ ! -e "${BASE_DIR}/${LIB_NAME}" ]
        then
            printf '%s does not exist, exiting\n' "${BASE_DIR}/${LIB_NAME}"
            exit 1
        fi
        # shellcheck source=lib.sh
        if ! . "${BASE_DIR}/${LIB_NAME}"
        then
            printf 'Could not load %s, exiting\n' "${BASE_DIR}/${LIB_NAME}"
            exit 1
        fi
    done
    unset LIB_NAMES

    # Do the job
    check_dot_env_file
    environment
    create_backup_dirs_and_log || fail_internal "Failed to create_backup_dirs_and_log"
    configure_testbed_ssh
    ARCHXFS_TGT_FILE="${BACKUP_DIR}/$(basename "${ARCHXFS_SRC_URL}")"
    download_archxfs

    DISTRO=archxfs
    [ -n "${1}" ] && DISTRO="${1}"
    case "${DISTRO}" in
        alma)
            SRC_URL="${ALMA_SRC_URL}"
           ;;
        ubuntu)
            SRC_URL="${UBUNTU_SRC_URL}"
            ;;
        redos)
            SRC_URL="${REDOS_SRC_URL}"
            ;;
        astra)
            SRC_URL="${ASTRA_SRC_URL}"
            ;;
        fedora)
            SRC_URL="${FEDORA_SRC_URL}"
            ;;
        archxfs)
            SRC_URL="${ARCHXFS_SRC_URL}"
            ;;
        arch)
            SRC_URL="${ARCH_SRC_URL}"
            ;;
        debian)
            SRC_URL="${DEBIAN_SRC_URL}"
            ;;
        artix)
            SRC_URL="${ARTIX_SRC_URL}"
            ;;
        alpine)
            SRC_URL="${ALPINE_SRC_URL}"
            ;;
        [[:upper:]]*)
            fail_internal "Distro name, lowercase"
            ;;
        *) fail_internal "Distro ${DISTRO} is not supported at the moment" ;;
    esac

    TARGET_VM_NAME="${DISTRO}-builder"
    TARGET_DISK_FILE="${BACKUP_DIR}/${DISTRO}-builder.qcow2"
    TGT_FILE="${BACKUP_DIR}/$(basename "${SRC_URL}")"
    download

    remove_vm
    build_disk

    CLOUD_INIT_ARGS=""
    [ "${DISTRO}" != "redos" ] && CLOUD_INIT_ARGS="--cloud-init meta-data=${BASE_DIR}/cloud-init/meta-data,user-data=${BASE_DIR}/cloud-init/user-data"
    virt-install --name "${TARGET_VM_NAME}" --memory 4096 --vcpus "$(cpu_count)" --cpu host-passthrough --disk path="${TARGET_DISK_FILE}",format=qcow2,bus=virtio --network network=default,model=virtio --graphics vnc,listen=0.0.0.0 --osinfo detect=on,require=off --channel unix,target.type=virtio,target.name=org.qemu.guest_agent.0 --import --noautoconsole \
    ${CLOUD_INIT_ARGS}

    printf '%s\n' "Connect to ${TARGET_VM_NAME} under cloud-init as admin/admin"
    printf '%s\n' "ssh admin@${TARGET_VM_NAME}"
    printf '%s\n' "For distros, except RedOS & Artix, wait for \`cloud-init status\` 'done'"
    printf '%s\n' "From host:"
    printf '%s\n' "scp -r ${BASE_DIR} admin@${TARGET_VM_NAME}:/home/admin/ ; scp ${ARCHXFS_TGT_FILE} admin@${TARGET_VM_NAME}:/home/admin/"
    printf '%s\n' "With guest, launch:"
    printf '%s\n' "/home/admin/libvirt-backup/testbed-configurator.sh"
    printf '%s\n' "If anything fails, check network connection, reboot the VM"
    printf '%s\n' "Once done, renew unix VM out of ${TARGET_DISK_FILE}:"
    printf '%s\n' "virsh shutdown ${TARGET_VM_NAME}; virsh shutdown unix; sleep 30; virsh list --name --state-running | grep -q unix && echo \"Still running, turn off manually\" && exit 1; virsh undefine --remove-all-storage unix; qemu-img convert -O qcow2 -c -o compression_type=zstd ${TARGET_DISK_FILE} ${BACKUP_DIR}/unix.qcow2; virt-install --name unix --memory 4096 --vcpus $(cpu_count) --cpu host-passthrough --disk path=${BACKUP_DIR}/unix.qcow2,format=qcow2,bus=virtio --network network=default,model=virtio --graphics vnc,listen=0.0.0.0 --osinfo detect=on,require=off --channel unix,target.type=virtio,target.name=org.qemu.guest_agent.0 --import --noautoconsole"

    unset BASE_DIR ARCHXFS_SRC_URL ARCHXFS_TGT_FILE DISTRO TARGET_VM_NAME TARGET_DISK_FILE SRC_URL TGT_FILE CLOUD_INIT_ARGS
}

closure "${@}"
