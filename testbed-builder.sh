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

print_builder_to_testbed_instruction() {
    printf '%s\n' "virsh shutdown ${TARGET_VM_NAME}; virsh shutdown ${TEST_HOSTNAME}; sleep 30; virsh list --name --state-running | grep -q ${TEST_HOSTNAME} && echo \"Still running, turn off manually\" && exit 1; virsh undefine --remove-all-storage ${TEST_HOSTNAME}; qemu-img convert -O qcow2 -c -o compression_type=zstd ${TARGET_DISK_FILE} ${BACKUP_DIR}/${TEST_HOSTNAME}.qcow2; virt-install --name ${TEST_HOSTNAME} --memory 4096 --vcpus $(cpu_count) --cpu host-passthrough --disk path=${BACKUP_DIR}/${TEST_HOSTNAME}.qcow2,format=qcow2,bus=virtio,cache=writeback --network network=default,model=virtio --graphics vnc,listen=0.0.0.0 --video virtio --osinfo detect=on,require=off --channel unix,target.type=virtio,target.name=org.qemu.guest_agent.0 --import --noautoconsole"
}

generate_cloud_init() {
    CLOUD_INIT_DIR="/tmp/cloud-init-${DISTRO}"
    mkdir -p "${CLOUD_INIT_DIR}"
cat << EOF > "${CLOUD_INIT_DIR}/meta-data"
instance-id: ${DISTRO}
local-hostname: ${DISTRO}
EOF
NO_USER_GROUP=""
if [ "${DISTRO}" = "ubuntu" ]
then
    NO_USER_GROUP="no_user_group: true"
fi
cat << EOF > "${CLOUD_INIT_DIR}/user-data"
#cloud-config
hostname: ${DISTRO}

users:
  - name: ${TEST_USERNAME}
    ${NO_USER_GROUP}
    uid: 10001
    groups: [sudo, wheel] # sudo debian/ubuntu, wheel the rest
    shell: /bin/sh
    sudo: "ALL=(ALL) ALL"
    lock_passwd: false
    passwd: $(openssl passwd -6 "${TEST_USERNAME}")
    ssh_authorized_keys:
      - $(cat "${BASE_DIR}/home/.ssh/id_rsa.pub")

ssh_pwauth: true
disable_root: false

# Re-use client SSH pair for server host key
ssh_deletekeys: true
ssh_keys:
  rsa_private: |
$(sed 's/^/    /' "${BASE_DIR}/home/.ssh/id_rsa")
  rsa_public: $(cat "${BASE_DIR}/home/.ssh/id_rsa.pub")
EOF
}

create_vm() {
    remove_vm
    build_disk
    CLOUD_INIT_ARGS=""
    CLOUD_INIT_DIR="/tmp"
    if [ "${DISTRO}" != "redos" ] && [ "${DISTRO}" != "artix" ]
    then
        generate_cloud_init
        CLOUD_INIT_ARGS="--cloud-init meta-data=${CLOUD_INIT_DIR}/meta-data,user-data=${CLOUD_INIT_DIR}/user-data"
    fi
    virt-install --name "${TARGET_VM_NAME}" --memory 4096 --vcpus "$(cpu_count)" --cpu host-passthrough --disk path="${TARGET_DISK_FILE}",format=qcow2,bus=virtio,cache=writeback --network network=default,model=virtio --graphics vnc,listen=0.0.0.0 --video virtio --osinfo detect=on,require=off --channel unix,target.type=virtio,target.name=org.qemu.guest_agent.0 --import --noautoconsole \
    ${CLOUD_INIT_ARGS}

    printf '%s\n' "Connect to ${TARGET_VM_NAME} under cloud-init as admin/admin"
    printf '%s\n' "ssh admin@${TARGET_VM_NAME}"
    printf '%s\n' "For distros, except RedOS & Artix, wait for \`cloud-init status\` 'done'"
    printf '%s\n' "From host:"
    printf '%s\n' "scp -r ${BASE_DIR} admin@${TARGET_VM_NAME}:/home/admin/ ; scp ${ARCHXFS_TGT_FILE} admin@${TARGET_VM_NAME}:/home/admin/"
    printf '%s\n' "With guest, launch:"
    printf '%s\n' "/home/admin/libvirt-backup/testbed-configurator.sh"
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
    check_dot_env_file
    environment
    create_backup_dirs_and_log || fail_internal "Failed to create_backup_dirs_and_log"
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

    configure_testbed_ssh "${DISTRO}"
    configure_testbed_ssh "${TARGET_VM_NAME}"

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
