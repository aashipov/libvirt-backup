#!/bin/sh

# ------------------------------------------------------------
#  testbed-builder.sh – Headless VM prototype generator
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

download() {
    if [ ! -e "${TGT_FILE}" ]
    then
        printf 'Downloading %s to %s\n' "${SRC_URL}" "${TGT_FILE}"
        if ! curl -fL --retry 3 -o "${TGT_FILE}.part" "${SRC_URL}"
        then
            rm -f "${TGT_FILE}.part"
            die "Failed to download ${SRC_URL}"
        fi
        mv "${TGT_FILE}.part" "${TGT_FILE}"
    fi

    if ! qemu-img check "${TGT_FILE}" > /dev/null 2>&1
    then
        die "Bad file ${TGT_FILE}: remove and re-run"
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
    LIB_SH="${BASE_DIR}/lib.sh"
    if [ ! -e "${LIB_SH}" ]
    then
        printf "${LIB_SH} does not exist, exiting\n"
        exit 1
    fi
    # shellcheck source=lib.sh
    if ! . "${LIB_SH}"
    then
        printf "Could not load ${LIB_SH}, exiting\n"
        exit 1
    fi
    unset LIB_SH

    # Do the job
    environment
    create_backup_dirs_and_log || die "Failed to create_backup_dirs_and_log"

    ALPINE_SRC_URL="https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/cloud/alpine-3.24.2-x86_64-cloudinit-r2.qcow2"
    ALPINE_TGT_FILE="${BACKUP_DIR}/$(basename "${ALPINE_SRC_URL}")"
    SRC_URL="${ALPINE_SRC_URL}"
    TGT_FILE="${ALPINE_TGT_FILE}"
    download

    DISTRO=debian
    SRC_URL="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
    [ -n "${1}" ] && DISTRO="${1}"
    case "${DISTRO}" in
        alma)
            SRC_URL="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-ext4-latest.x86_64.qcow2"
            SRC_URL="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
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
        fedora)
            SRC_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/44/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2"
            ;;
        debian) ;;
        [[:upper:]]*) die "Distro name, lowercase" ;;
        *) die "Distro ${DISTRO} is not supported at the moment" ;;
    esac

    TARGET_VM_NAME="${DISTRO}-builder"
    TARGET_DISK_FILE="${BACKUP_DIR}/${DISTRO}-builder.qcow2"
    TGT_FILE="${BACKUP_DIR}/$(basename "${SRC_URL}")"
    download

    remove_vm
    build_disk

    CLOUD_INIT_ARGS=""
    [ "${DISTRO}" != "redos" ] && CLOUD_INIT_ARGS="--cloud-init meta-data="${BASE_DIR}"/cloud-init/meta-data,user-data="${BASE_DIR}"/cloud-init/user-data"
    virt-install --name "${TARGET_VM_NAME}" --memory 4096 --vcpus "$(cpu_count)" --cpu host-passthrough --disk path="${TARGET_DISK_FILE}",format=qcow2,bus=virtio --network network=default,model=virtio --graphics vnc,listen=0.0.0.0 --osinfo detect=on,require=off --channel unix,target.type=virtio,target.name=org.qemu.guest_agent.0 --import --noautoconsole \
    ${CLOUD_INIT_ARGS}

    printf '%s\n' "Connect to ${TARGET_VM_NAME} under cloud-init"
    printf '%s\n' "setsid --fork virt-manager --connect qemu:///system --show-domain-console ${TARGET_VM_NAME}"
    printf '%s\n' "wait for \`cloud-init status\` 'done'"
    printf '%s\n' "cd ${BASE_DIR} && virsh shutdown ${TARGET_VM_NAME} ; sleep 30s && virt-copy-in -d ${TARGET_VM_NAME} testbed-configurator.sh /home/admin/ && virt-copy-in -d ${TARGET_VM_NAME} ${ALPINE_TGT_FILE} /home/admin/ && virsh start ${TARGET_VM_NAME}"
    printf '%s\n' "Connect via virt-manager"
    printf '%s\n' "setsid --fork virt-manager --connect qemu:///system --show-domain-console ${TARGET_VM_NAME}"
    printf '%s\n' "or via SSH"
    printf '%s\n' "ssh admin@${TARGET_VM_NAME}"
    printf '%s\n' "authenticate admin/admin & launch"
    printf '%s\n' "./testbed-configurator.sh"
    printf '%s\n' "If anything fails, check network connection, log-out and re-login"
    printf '%s\n' "Copy ssh pair out"
    printf '%s\n' "virt-copy-out -d ${TARGET_VM_NAME} /home/admin/.ssh/id_rsa{,.pub} ~/.ssh/unix/ && chmod 0600 ~/.ssh/unix/id_rsa"
    printf '%s\n' "Rename ${TARGET_DISK_FILE} and attach to the unix VM"

    unset BASE_DIR ALPINE_SRC_URL ALPINE_TGT_FILE DISTRO TARGET_VM_NAME TARGET_DISK_FILE SEED_ISO_FILE SRC_URL TGT_FILE CLOUD_INIT_ARGS
}

closure "${@}"
