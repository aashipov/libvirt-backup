#!/bin/sh

# ------------------------------------------------------------
#  test-vms-builder.sh – Test VMs generator
# ------------------------------------------------------------

closure() {
    cd /tmp/
    sudo virsh net-edit default
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

    sudo mkdir -p /backup-vm/ /other_backup/
    sudo setfacl -d -R -m u:administrator:rwx /backup-vm/ /other_backup/
    sudo chown -R administrator:administrator /backup-vm/ /other_backup/
    unset ALPINE_ISO_URL ALPINE_ISO_FILE
}

closure
