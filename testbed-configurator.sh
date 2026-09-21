#!/bin/sh

# ------------------------------------------------------------
# testbed-configurator.sh – Post-cloud-init configurator, as unprivileged administrator
# virsh shutdown debian-builder
# virt-copy-in -d debian-builder testbed-configurator.sh /home/administrator/
# virsh start debian-builder
# virsh console debian-builder
# Proceed with testbed-configurator.sh
# ------------------------------------------------------------

configure_ssh() {
    mkdir -p /home/administrator/.ssh/ && ssh-keygen -t rsa -b 4096 -C "dummy@dummy.org" -f /home/administrator/.ssh/id_rsa && chmod 0600 /home/administrator/.ssh/id_rsa && ssh-copy-id 127.0.0.2
}

configure_vms() {
    ALPINE_ISO_URL="https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/cloud/generic_alpine-3.24.1-x86_64-bios-tiny-r0.qcow2"
    ALPINE_ISO_FILE="/tmp/$(basename ${ALPINE_ISO_URL})"
    if [ ! -f "${ALPINE_ISO_FILE}" ]
    then
        curl -L -o "${ALPINE_ISO_FILE}" "${ALPINE_ISO_URL}"
    fi
    qemu-img convert -O qcow2 -c -o compression_type=zstd generic_alpine*.qcow2 prototype.qcow2
    qemu-img create -f qcow2 -o compression_type=zstd blank-prototype.qcow2 256M

    for item in a b c; do
      sudo cp prototype.qcow2 /var/lib/libvirt/images/"$item".qcow2
      sudo cp blank-prototype.qcow2 /var/lib/libvirt/images/"$item$item".qcow2
    done

    sudo chmod 0755 /var/lib/libvirt/images

    for item in a b c; do
      virt-install --name "$item" --ram 768 --vcpus 2 \
        --disk path=/var/lib/libvirt/images/"$item".qcow2,format=qcow2,bus=virtio \
        --disk path=/var/lib/libvirt/images/"$item$item".qcow2,format=qcow2,bus=virtio \
        --network network=default,model=virtio \
        --graphics vnc,listen=0.0.0.0 \
        --osinfo detect=on,require=off \
        --import --noautoconsole --noreboot
    done
    unset ALPINE_ISO_URL ALPINE_ISO_FILE
}

configure_backup_dirs() {
    sudo mkdir -p /backup-vm/ /other_backup/
    sudo setfacl -d -R -m u:administrator:rwx /backup-vm/ /other_backup/
    sudo chown -R administrator:administrator /backup-vm/ /other_backup/
}

closure() {
    set -e
    #set -x # Debug

    DISTRO=debian
    [ ! -z "${1}" ] && DISTRO="${1}"

    [ -f "${HOME}/configured" ] && printf '%s\n' "Already configured, exiting" && exit 0

    configure_ssh

    cd /tmp/
    if [ "${DISTRO}" = "debian" ]
    then
        sudo virsh net-edit default
    fi
    sudo virsh net-autostart default 
    sudo virsh net-start default
    configure_vms

    configure_backup_dirs

    touch "${HOME}/configured"
    printf '%s\n' "Copy ssh pair out: virt-copy-out -d ${DISTRO}-builder /home/administrator/.ssh/id_rsa{,.pub} ~/.ssh/unix/ && chmod 0600 ~/.ssh/unix/id_rsa"
    sudo poweroff
    unset DISTRO
}

closure "${@}"
