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
# "${HOME}/testbed-configurator.sh" debian
# virt-copy-out -d debian-builder /home/administrator/.ssh/id_rsa{,.pub} ~/.ssh/unix/ && chmod 0600 ~/.ssh/unix/id_rsa
# ------------------------------------------------------------

rhel_privileged() {
    sudo dnf -y upgrade
    sudo dnf -y config-manager --enable crb
    sudo dnf -y install epel-release
    sudo dnf -y config-manager --disable epel-cisco-openh264
    sudo dnf -y install cronie git rsync acl sudo qemu-kvm libvirt virt-install mc tree curl
    sudo dnf -y install xorg-x11-server-Xorg virt-manager xrdp xorgxrdp openbox chromium firefox thunar xfce4-terminal xfce4-taskmanager mousepad dbus-daemon gvfs gvfs-smb weston #gvfs-sftp
    sudo dnf -y remove cloud-init
    sudo dnf -y clean all
    sudo systemctl enable --now crond
}

redos_privileged() {
    sudo dnf -y upgrade
    sudo dnf -y install cronie git rsync acl sudo qemu-kvm libvirt virt-install mc tree curl
    sudo dnf -y install xorg-x11-server-Xorg virt-manager xrdp xorgxrdp openbox chromium firefox thunar xfce4-terminal xfce4-taskmanager mousepad dbus-daemon gvfs gvfs-smb weston #gvfs-sftp
    sudo dnf -y clean all
    sudo systemctl enable --now crond
}

debian_privileged() {
cat << 'EOF' | sudo tee /etc/systemd/network/99-ethernet.network
[Match]
Name=en*

[Network]
DHCP=yes
EOF
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update && sudo apt-get -y upgrade
    sudo apt-get install -y cron git rsync acl qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils tree curl mc openssh-server systemd-resolved
    sudo apt-get install -y virt-manager weston winpr3-utils xrdp xorgxrdp openbox chromium firefox-esr thunar xfce4-terminal xfce4-taskmanager mousepad gvfs gvfs-backends
    sudo apt-get remove -y cloud-init
    sudo apt clean && sudo apt -y autoremove
    sudo systemctl enable --now cron
}

ubuntu_privileged() {
cat << 'EOF' | sudo tee /etc/systemd/network/99-ethernet.network
[Match]
Name=en*

[Network]
DHCP=yes
EOF
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update && sudo apt-get -y upgrade
    sudo apt-get install -y cron git rsync acl qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils tree curl mc openssh-server
    sudo apt-get install -y virt-manager weston winpr-utils xrdp xorgxrdp openbox thunar xfce4-terminal xfce4-taskmanager mousepad gvfs gvfs-backends
    sudo snap remove lxd
    sudo apt-get remove -y snapd cloud-init modemmanager
    sudo apt clean && sudo apt -y autoremove
    sudo systemctl disable dbus
    sudo systemctl enable --now cron
}

astra_privileged() {
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update
    sudo apt-get install -y cron git rsync acl qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils tree curl mc openssh-server
    sudo apt-get install -y virt-manager weston winpr-utils xrdp xorgxrdp openbox chromium firefox gvfs gvfs-backends mate-terminal nautilus geany gvfs gvfs-backends
    sudo apt-get remove -y cloud-init
    sudo apt clean && sudo apt -y autoremove
    sudo systemctl enable --now cron
    if [ ! -e /usr/bin/xfce4-terminal ]
    then
        sudo ln -s /usr/bin/mate-terminal /usr/bin/xfce4-terminal
    fi
}

tune_xinitrc() {
    cat << 'EOF' | tee "${HOME}/.xinitrc"
#!/bin/sh
export XDG_CURRENT_DESKTOP=openbox
exec dbus-run-session -- openbox-session
EOF
    cd "${HOME}"
    chmod +x .xinitrc
    if [ ! -e "${HOME}/.xsession" ]
    then
        ln -s .xinitrc .xsession
    fi
    if [ ! -e "${HOME}/.Xclients" ]
    then
        ln -s .xinitrc .Xclients
    fi
    if [ ! -e "${HOME}/startwm.sh" ]
    then
        ln -s .xinitrc startwm.sh
    fi
}

configure_ssh() {
    mkdir -p "${HOME}/.ssh/" && ssh-keygen -t rsa -b 4096 -C "dummy@dummy.org" -f "${HOME}/.ssh/id_rsa" && chmod 0600 "${HOME}/.ssh/id_rsa" && ssh-copy-id 127.0.0.2
}

configure_vms() {
    cd "${HOME}"
    ALPINE_QCOW2_URL="https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/cloud/generic_alpine-3.24.1-x86_64-bios-tiny-r0.qcow2"
    ALPINE_QCOW2_FILE="${HOME}/$(basename ${ALPINE_QCOW2_URL})"
    if [ ! -f "${ALPINE_QCOW2_FILE}" ]
    then
        curl -L -o "${ALPINE_QCOW2_FILE}" "${ALPINE_QCOW2_URL}"
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
    unset ALPINE_QCOW2_URL ALPINE_QCOW2_FILE
}

configure_backup_dirs() {
    sudo mkdir -p /backup-vm/ /other_backup/
    sudo setfacl -d -R -m u:"${USER}":rwx /backup-vm/ /other_backup/
    sudo chown -R "${USER}":"${USER}" /backup-vm/ /other_backup/
}

closure() {
    set -e
    #set -x # Debug

    [ -f "${HOME}/configured" ] && printf '%s\n' "Already configured, exiting" && exit 0

    DISTRO=debian
    [ -n "${1}" ] && DISTRO="${1}"
    case "${DISTRO}" in
        debian)
            debian_privileged
            sudo virsh net-edit default
            ;;
        [[:upper:]]*) die "Distro name, lowercase" ;;
        alma)
            rhel_privileged
           ;;
        ubuntu)
            ubuntu_privileged
            ;;
        redos)
            redos_privileged
            ;;
        astra)
            astra_privileged
            sudo virsh net-edit default
            ;;
           *) die "Distro ${DISTRO} is not supported at the moment" ;;
    esac

    sudo groupmod -g "10001" "${USER}"
    if [ "${DISTRO}" = "astra" ]
    then
        sudo usermod -aG libvirt-admin "${USER}"
        sudo usermod -aG kvm "${USER}"
    fi
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
