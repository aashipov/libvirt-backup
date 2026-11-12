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

remove_vm() {
    if virsh list --all | grep -q "\b${TARGET_VM_NAME}\b"
    then
        if virsh list --name --state-running | grep -q "${TARGET_VM_NAME}"
        then
            virsh destroy "${TARGET_VM_NAME}" || die "Failed to destroy ${TARGET_VM_NAME}"
        fi
        while virsh list --name --state-running | grep -q "\b${TARGET_VM_NAME}\b"
        do
            printf '%s is still running. Waiting...\n' "${TARGET_VM_NAME}"
            sleep 5
        done
        printf '%s has shut down.\n' "${TARGET_VM_NAME}"
        virsh undefine "${TARGET_VM_NAME}" || die "Failed to undefine ${TARGET_VM_NAME}"
        rm -rf "${TARGET_DISK_FILE}"
    fi
}

build_disk() {
    TARGET_DISK_CAPACITY="32G"
    if [ ! -f "${TARGET_DISK_FILE}" ]
    then
        qemu-img convert -O qcow2 -o compression_type=zstd -c "${TGT_FILE}" "${TARGET_DISK_FILE}" || die "Failed to convert ${TGT_FILE} to ${TARGET_DISK_FILE}"
        qemu-img resize "${TARGET_DISK_FILE}" "${TARGET_DISK_CAPACITY}" || die "Failed to resize ${TARGET_DISK_FILE} to ${TARGET_DISK_CAPACITY}"
    fi
    unset TARGET_DISK_CAPACITY
}

cpu_count() {
    CPU_COUNT=$(($(getconf _NPROCESSORS_ONLN) + 0))
    printf '%d\n' "${CPU_COUNT}"
    unset CPU_COUNT
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

prime_alpine() {
    SRC_URL="${ALPINE_SRC_URL}"
    TGT_FILE="${ALPINE_TGT_FILE}"
    ALPINE_TGT_FILE_PRIMED="${ALPINE_TGT_FILE}.primed"
    if [ ! -e "${ALPINE_TGT_FILE_PRIMED}" ]
    then
        download
        virt-customize -a "${ALPINE_TGT_FILE}" --install qemu-guest-agent --run-command 'rc-update add qemu-guest-agent default' || die "virt-customize failed for ${ALPINE_TGT_FILE}"
        touch "${ALPINE_TGT_FILE_PRIMED}"
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
    # Load library
    LIB_SH="${BASE_DIR}/lib.sh"
    if [ ! -e "${LIB_SH}" ]
    then
        printf '%s does not exist, exiting\n' "${LIB_SH}"
        exit 1
    fi
    # shellcheck source=lib.sh
    if ! . "${LIB_SH}"
    then
        printf 'Could not load %s, exiting\n' "${LIB_SH}"
        exit 1
    fi
    unset LIB_SH

    # Do the job
    environment
    create_backup_dirs_and_log || die "Failed to create_backup_dirs_and_log"

    ALPINE_SRC_URL="https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/cloud/alpine-3.23.6-x86_64-bios-tiny-r0.qcow2"
    ALPINE_TGT_FILE="${BACKUP_DIR}/$(basename "${ALPINE_SRC_URL}")"
    prime_alpine

    DISTRO=arch
    [ -n "${1}" ] && DISTRO="${1}"
    case "${DISTRO}" in
        alma)
            SRC_URL="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
           ;;
        ubuntu)
            SRC_URL="https://cloud-images.ubuntu.com/releases/jammy/release/ubuntu-22.04-server-cloudimg-amd64.img"
            ;;
        redos)
            SRC_URL="https://github.com/aashipov/libvirt-backup/releases/download/store/redos-8-20260716.0-x86_64-post-cloud-init.qcow2"
            ;;
        astra)
            SRC_URL="https://registry.astralinux.ru/artifactory/mg-generic/alse/cloudinit/alse-1.8.7-base-cloudinit-mg16.7.0-amd64.qcow2"
            ;;
        fedora)
            SRC_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/44/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2"
            ;;
        arch)
            SRC_URL="https://fastly.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2"
            ;;
        debian)
            SRC_URL="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
            ;;
        artix)
            SRC_URL="https://github.com/aashipov/libvirt-backup/releases/download/store/artix-base-openrc-20261102-x86_64-post-cloud-init.qcow2"
            ;;
        [[:upper:]]*)
            die "Distro name, lowercase"
            ;;
        *) die "Distro ${DISTRO} is not supported at the moment" ;;
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
    printf '%s\n' "scp -r ${BASE_DIR} admin@${TARGET_VM_NAME}:/home/admin/ ; scp ${ALPINE_TGT_FILE} admin@${TARGET_VM_NAME}:/home/admin/"
    printf '%s\n' "With guest, launch:"
    printf '%s\n' "/home/admin/libvirt-backup/testbed-configurator.sh"
    printf '%s\n' "If anything fails, check network connection, reboot the VM"
    printf '%s\n' "From host, copy guest ssh pair out:"
    printf '%s\n' "scp admin@${TARGET_VM_NAME}:/home/admin/.ssh/id_rsa{,.pub} ~/.ssh/unix/ && chmod 0600 ~/.ssh/unix/id_rsa"
    printf '%s\n' "Rename ${TARGET_DISK_FILE} and attach to the unix VM"

    unset BASE_DIR ALPINE_SRC_URL ALPINE_TGT_FILE DISTRO TARGET_VM_NAME TARGET_DISK_FILE SRC_URL TGT_FILE CLOUD_INIT_ARGS
}

closure "${@}"
