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

create_vm() {
    remove_vm
    build_disk
    CLOUD_INIT_ARGS=""
    CLOUD_INIT_DIR="/tmp"
    if [ "${DISTRO}" != "artix" ]
    then
        generate_cloud_init
        CLOUD_INIT_ARGS="--cloud-init meta-data=${CLOUD_INIT_DIR}/meta-data,user-data=${CLOUD_INIT_DIR}/user-data"
    fi
    virt-install --name "${TARGET_VM_NAME}" --memory 4096 --vcpus "$(cpu_count)" --cpu host-passthrough --disk path="${TARGET_DISK_FILE}",format=qcow2,bus=virtio,cache=writeback --network network=default,model=virtio --graphics vnc,listen=0.0.0.0 --video virtio --osinfo detect=on,require=off --channel unix,target.type=virtio,target.name=org.qemu.guest_agent.0 --channel qemu-vdagent,source.clipboard.copypaste=on,source.mouse.mode=client,target.type=virtio,target.name=com.redhat.spice.0 --import --noautoconsole \
    ${CLOUD_INIT_ARGS}

    printf '%s\n' "Connect to ${TARGET_VM_NAME} under cloud-init as ${TEST_USERNAME}/${TEST_USERNAME}"
    printf '%s\n' "ssh ${TEST_USERNAME}@${TARGET_VM_NAME}"
    printf '%s\n' "Wait for \`cloud-init status\` 'done' (distros except Artix)"
    printf '%s\n' "From host:"
    printf '%s\n' "scp -r ${BASE_DIR} ${TEST_USERNAME}@${TARGET_VM_NAME}:/home/${TEST_USERNAME}/ ; scp ${ARCHXFS_TGT_FILE} ${TEST_USERNAME}@${TARGET_VM_NAME}:/home/${TEST_USERNAME}/"
    printf '%s\n' "With guest, launch:"
    printf '%s\n' "/home/${TEST_USERNAME}/libvirt-backup/testbed-configurator.sh"
    printf '%s\n' "If anything fails, check network connection, reboot the VM"
    printf '%s\n' "Once done, renew ${TEST_HOSTNAME} VM out of ${TARGET_DISK_FILE}:"
    print_builder_to_testbed_instruction
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
            printf '%s does not exist, exiting\n' "${BASE_DIR}/${LIB_NAME}" >&2
            exit 1
        fi
        # shellcheck source=lib.sh
        if ! . "${BASE_DIR}/${LIB_NAME}"
        then
            printf 'Could not load %s, exiting\n' "${BASE_DIR}/${LIB_NAME}" >&2
            exit 1
        fi
    done
    unset LIB_NAMES

    # Do the job
    DISTRO=archxfs
    [ -n "${1}" ] && DISTRO="${1}"
    
    check_dot_env_file
    environment
    create_backup_dirs_and_log || fail_internal "Failed to create_backup_dirs_and_log"
    ARCHXFS_TGT_FILE="${BACKUP_DIR}/$(basename "${ARCHXFS_SRC_URL}")"
    download_archxfs

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
        debianxfs)
            SRC_URL="${DEBIAN_XFS_SRC_URL}"
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

    configure_testbed_ssh "${DISTRO}" "${TEST_USERNAME}"
    configure_testbed_ssh "${TARGET_VM_NAME}" "${TEST_USERNAME}"
    configure_testbed_certificates

    VM_LIST="$(virsh list --all --name)" || fail_internal "Failed to list VMs"
    if printf '%s\n' "${VM_LIST}" | grep -q "${TARGET_VM_NAME}"
    then
        if yes_no_dialog "${TARGET_VM_NAME} exists, would you like to recreate it?"
        then
            create_vm
        else
            printf '%s\n' "If you know that ${TARGET_VM_NAME} prototype VM is consistent and want to renew ${TEST_HOSTNAME} VM out of it, follow instructions below"
            print_builder_to_testbed_instruction
        fi
    else
        create_vm
    fi

    unset BASE_DIR ARCHXFS_SRC_URL ARCHXFS_TGT_FILE DISTRO TARGET_VM_NAME TARGET_DISK_FILE SRC_URL TGT_FILE CLOUD_INIT_ARGS CLOUD_INIT_DIR VM_LIST
}

closure "${@}"
