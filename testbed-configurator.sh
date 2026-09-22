#!/bin/sh

# ------------------------------------------------------------
# testbed-configurator.sh – Post-cloud-init configurator, as unprivileged administrator
# 
# cloud-init does not handle complex configuration well, it's simpler than ansible though
# This script performs post cloud-init prototype configuration
# 
# virsh shutdown debian-builder
# virt-copy-in -d debian-builder testbed-configurator.sh /home/administrator/
# virsh start debian-builder
# virsh console debian-builder
# Proceed with testbed-configurator.sh
# ------------------------------------------------------------

debian_privileged() {
    cat << 'EOF' | sudo tee /etc/systemd/network/99-ethernet.network
[Match]
Name=en*

[Network]
DHCP=yes
EOF
    sudo apt-get update && sudo apt-get -y upgrade
    sudo apt-get install -y cron git rsync acl qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils tree curl mc openssh-server systemd-resolved
    sudo apt-get install -y virt-manager weston winpr3-utils xrdp xorgxrdp openbox chromium firefox-esr thunar xfce4-terminal xfce4-taskmanager mousepad gvfs gvfs-backends
    sudo apt clean && sudo apt autoremove
    sudo apt-get remove -y cloud-init
    sudo systemctl enable --now cron
}

rhel_privileged() {
    sudo dnf -y upgrade
    sudo dnf -y install epel-release
    sudo dnf -y config-manager --disable epel-cisco-openh264
    sudo dnf -y install cronie git rsync acl sudo qemu-kvm libvirt virt-install cockpit mc tree curl
    sudo dnf -y install xorg-x11-server-Xorg xorg-x11-xauth xorg-x11-utils virt-manager xrdp openbox chromium firefox thunar xfce4-terminal xfce4-taskmanager mousepad dbus-daemon gvfs gvfs-smb weston #gvfs-sftp
    sudo dnf -y remove cloud-init
    sudo dnf -y clean all
    sudo systemctl enable --now crond
}

tune_xinitrc() {
    cat << 'EOF' | tee ${HOME}/.xinitrc
#!/bin/sh
export XDG_CURRENT_DESKTOP=openbox
exec dbus-run-session -- openbox-session
EOF
cd ${HOME} && chmod +x .xinitrc && ln -s .xinitrc .xsession && ln -s .xinitrc .Xclients && ln -s .xinitrc startwm.sh
}

configure_ssh() {
    mkdir -p ${HOME}/.ssh/ && ssh-keygen -t rsa -b 4096 -C "dummy@dummy.org" -f ${HOME}/.ssh/id_rsa && chmod 0600 ${HOME}/.ssh/id_rsa && ssh-copy-id 127.0.0.2
}

configure_vms() {
    cd /tmp/
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
    sudo setfacl -d -R -m u:${USER}:rwx /backup-vm/ /other_backup/
    sudo chown -R ${USER}:${USER} /backup-vm/ /other_backup/
}

closure() {
    set -e
    #set -x # Debug

    DISTRO=debian
    [ ! -z "${1}" ] && DISTRO="${1}"

    [ -f "${HOME}/configured" ] && printf '%s\n' "Already configured, exiting" && exit 0

    [ ! -z "${1}" ] && DISTRO="${1}"
    case "${DISTRO}" in
        debian)
            debian_privileged
            sudo virsh net-edit default
            ;;
        [[:upper:]]*) die "Distro name, lowercase" ;;
        alma)
            rhel_privileged
           ;;
           *) die "Distro ${DISTRO} is not supported at the moment" ;;
    esac

    sudo groupmod -g "10001" "${USER}"
    sudo usermod -aG libvirt "${USER}"
    sudo systemctl enable --now libvirtd xrdp

    configure_backup_dirs

    mkdir -p "${HOME}/.config/libvirt/"
    printf '%s\n' "uri_default = \"qemu:///system\"" > "${HOME}/.config/libvirt/libvirt.conf"
    sudo virsh net-autostart default
    tune_xinitrc
    configure_vms
    configure_ssh

    touch "${HOME}/configured"
    printf '%s\n' "Copy ssh pair out: virt-copy-out -d ${DISTRO}-builder ${HOME}/.ssh/id_rsa{,.pub} ~/.ssh/unix/ && chmod 0600 ~/.ssh/unix/id_rsa"
    sudo poweroff
    unset DISTRO
}

closure "${@}"
