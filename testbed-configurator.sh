#!/bin/sh

# ------------------------------------------------------------
# testbed-configurator.sh – Post-cloud-init configurator, as unprivileged admin
#
# cloud-init does not handle complex configuration well, it's simpler than ansible though.
# It handles default user creation well.
# This script performs post cloud-init prototype configuration, suits non-cloud-init VM/baremetal as well.
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

adjust_default_network() {
    DEFAULT_NETWORK_NAME=default
    if virsh net-list | grep -q "${DEFAULT_NETWORK_NAME}"
    then
        virsh net-destroy "${DEFAULT_NETWORK_NAME}"
    fi
    if virsh net-list --all | grep -q "${DEFAULT_NETWORK_NAME}"
    then
        virsh net-undefine "${DEFAULT_NETWORK_NAME}"
        sleep 5
    fi
    NETWORK_XML=/tmp/network.xml
cat << 'EOF' > /tmp/network.xml
<network>
  <name>default</name>
  <forward mode='nat'/>
  <bridge name='virbr0' stp='on' delay='0'/>
  <ip address='192.168.123.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.123.2' end='192.168.123.254'/>
    </dhcp>
  </ip>
</network>
EOF
    virsh net-define "${NETWORK_XML}"
    virsh net-start "${DEFAULT_NETWORK_NAME}"
    rm "${NETWORK_XML}"
    unset DEFAULT_NETWORK_NAME NETWORK_XML
}

configure_libvirt() {
    sudo groupmod -g "10001" "${USER}"
    sudo usermod -aG libvirt "${USER}"

    if [ -d /run/systemd/system ]
    then
      sudo systemctl enable --now libvirtd
    fi
    
    if [ "${DISTRO}" = "debian" ] || [ "${DISTRO}" = "astra" ] || [ "${DISTRO}" = "arch" ] || [ "${DISTRO}" = "artix" ]
    then
        adjust_default_network
    fi
    virsh net-autostart default
}

rhel_privileged() {
    sudo dnf -y upgrade
    sudo dnf -y config-manager --enable crb
    sudo dnf -y install epel-release
    sudo dnf -y config-manager --disable epel-cisco-openh264
    sudo dnf -y install cronie git rsync acl sudo qemu-kvm libvirt virt-install mc tree curl qemu-guest-agent
    sudo dnf -y install xorg-x11-server-Xorg virt-manager xrdp xorgxrdp openbox chromium firefox thunar xfce4-terminal xfce4-taskmanager mousepad dbus-daemon gvfs gvfs-smb weston dmenu
    sudo dnf -y remove cloud-init
    sudo dnf -y clean all
    sudo systemctl enable --now crond
}

redos_privileged() {
    sudo dnf -y upgrade
    sudo dnf -y install cronie git rsync acl sudo qemu-kvm libvirt virt-install mc tree curl qemu-guest-agent
    sudo dnf -y install xorg-x11-server-Xorg virt-manager xrdp xorgxrdp openbox chromium firefox thunar xfce4-terminal xfce4-taskmanager mousepad dbus-daemon gvfs gvfs-smb weston dmenu
    sudo dnf -y clean all
    sudo systemctl enable --now crond
}

fedora_privileged() {
    sudo dnf -y upgrade
    sudo dnf -y config-manager disable fedora-cisco-openh264
    sudo dnf -y install cronie git rsync acl sudo qemu-kvm libvirt virt-install mc tree curl qemu-guest-agent
    sudo dnf -y install xorg-x11-server-Xorg virt-manager xrdp xorgxrdp openbox chromium firefox thunar xfce4-terminal xfce4-taskmanager mousepad dbus-daemon gvfs gvfs-smb weston dmenu
    sudo dnf -y remove cloud-init
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
    sudo apt-get install -y cron git rsync acl qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils tree curl mc openssh-server systemd-resolved qemu-guest-agent
    sudo apt-get install -y virt-manager weston winpr3-utils xrdp xorgxrdp openbox chromium firefox-esr thunar xfce4-terminal xfce4-taskmanager mousepad gvfs gvfs-backends suckless-tools
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
    sudo apt-get install -y cron git rsync acl qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils tree curl mc openssh-server qemu-guest-agent
    sudo apt-get install -y virt-manager weston winpr-utils xrdp xorgxrdp openbox thunar xfce4-terminal xfce4-taskmanager mousepad gvfs gvfs-backends dmenu
    if which snap > /dev/null 2>&1
    then
        sudo snap remove lxd
    fi
    sudo apt-get remove -y snapd cloud-init modemmanager
    sudo apt clean && sudo apt -y autoremove
    sudo systemctl disable dbus
    sudo systemctl enable --now cron
}

astra_privileged() {
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update
    sudo apt-get install -y cron git rsync acl qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils tree curl mc openssh-server qemu-guest-agent
    sudo apt-get install -y virt-manager weston winpr-utils xrdp xorgxrdp openbox chromium firefox gvfs gvfs-backends mate-terminal nautilus geany gvfs gvfs-backends #suckless-tools
    sudo apt-get remove -y cloud-init
    sudo apt clean && sudo apt -y autoremove
    sudo systemctl enable --now cron
    if [ ! -e /usr/bin/xfce4-terminal ]
    then
        sudo ln -s /usr/bin/mate-terminal /usr/bin/xfce4-terminal
    fi
    sudo update-locale LANG=C
    sudo usermod -aG libvirt-admin "${USER}"
    sudo usermod -aG kvm "${USER}"
}

arch_install_if_missing() {
    if [ -n "${1}" ]
    then
        for package in ${1}
        do
            if ! pacman -Qi "${package}" &> /dev/null
            then
                sudo pacman --noconfirm -S "${package}"
            fi
        done
    fi
}

arch_remove_if_installed() {
    if [ -n "${1}" ]
    then
        for package in ${1}
        do
            if pacman -Qi "${package}" &> /dev/null
            then
                sudo pacman --noconfirm -Rns "${package}"
            fi
        done
    fi
}

arch_privileged() {
    sudo pacman --noconfirm -Syu
    arch_install_if_missing "cronie git rsync acl qemu-desktop libvirt tree curl mc openssh qemu-guest-agent networkmanager vim dnsmasq"
    arch_install_if_missing "virt-manager weston freerdp openbox chromium firefox thunar xfce4-terminal xfce4-taskmanager mousepad gvfs gvfs-smb gnome-themes-extra adwaita-icon-theme"
    arch_install_if_missing "debugedit fakeroot patch autoconf automake libtool pkg-config gcc make xorg-xinit dmenu"
    mkdir -p "${HOME}"/arch/
    cd "${HOME}"/arch/
    if [ ! -d "${HOME}"/arch/xrdp ]
    then
        git clone https://aur.archlinux.org/xrdp.git
        cd xrdp
        makepkg -si
        sudo sed -i.bak 's/^#\s*SessionSockdirGroup=xrdp/SessionSockdirGroup=xrdp/' /etc/xrdp/sesman.ini
    fi
    cd "${HOME}"/arch/
    if [ ! -d "${HOME}"/arch/xorgxrdp ]
    then
        git clone https://aur.archlinux.org/xorgxrdp.git
        cd xorgxrdp
        gpg --keyserver keys.gnupg.net --recv-keys 03993B4065E7193B
        makepkg -si
    fi
    arch_remove_if_installed "cloud-init linux-firmware"
    DEBUG_PACKAGES_TO_DROP="$(pacman -Qe | grep "debug" | cut -d ' ' -f 1 |  tr '\n' ' ')"
    if [ -n "${DEBUG_PACKAGES_TO_DROP}" ]
    then
        for package in ${DEBUG_PACKAGES_TO_DROP}
        do
            sudo pacman -Rns --noconfirm "${package}"
        done
    fi
    sudo systemctl enable --now cronie NetworkManager
    if [ ! -e /usr/bin/vi ]
    then
        sudo ln -s /usr/bin/vim /usr/bin/vi
    fi
}

artix_privileged() {
    sudo pacman --noconfirm -Syu
    arch_install_if_missing "cronie cronie-openrc git rsync acl tree curl mc openssh networkmanager vim dnsmasq xfsprogs"
    arch_install_if_missing "weston freerdp openbox chromium firefox thunar xfce4-terminal xfce4-taskmanager mousepad gvfs gvfs-smb gnome-themes-extra adwaita-icon-theme"
    arch_install_if_missing "debugedit fakeroot patch autoconf automake libtool pkg-config gcc make xorg-xinit dmenu xrdp"
    arch_install_if_missing "qemu-full libvirt libvirt-openrc dnsmasq dmidecode openbsd-netcat virt-manager"
    mkdir -p "${HOME}"/arch/
    cd "${HOME}"/arch/
    if [ ! -d "${HOME}"/arch/xorgxrdp ]
    then
        git clone https://aur.archlinux.org/xorgxrdp.git
        cd xorgxrdp
        gpg --keyserver keys.gnupg.net --recv-keys 03993B4065E7193B
        makepkg -si
    fi
    arch_remove_if_installed "cloud-init linux-firmware"
    DEBUG_PACKAGES_TO_DROP="$(pacman -Qe | grep "debug" | cut -d ' ' -f 1 |  tr '\n' ' ')"
    if [ -n "${DEBUG_PACKAGES_TO_DROP}" ]
    then
        for package in ${DEBUG_PACKAGES_TO_DROP}
        do
            sudo pacman -Rns --noconfirm "${package}"
        done
    fi
    sudo rc-update add NetworkManager default
    sudo rc-update add cronie default
    sudo rm -f /run/xrdp.pid /run/xrdp-sesman.pid
    sudo cp "${BASE_DIR}/artix/"* /etc/init.d/
    sudo rc-update add xrdp default
    sudo rc-update add xrdp-sesman default
    sudo rc-update add virtlogd default
    sudo rc-update add libvirtd default
    if [ ! -e /usr/bin/vi ]
    then
        sudo ln -s /usr/bin/vim /usr/bin/vi
    fi
}

configure_ssh() {
    mkdir -p "${HOME}/.ssh"
    if [ ! -f "${HOME}/.ssh/id_rsa" ]
    then
        ssh-keygen -t rsa -b 4096 -N "" -C "dummy@dummy.org" -f "${HOME}/.ssh/id_rsa"
        chmod 0600 "${HOME}/.ssh/id_rsa"
    fi
    ssh-copy-id 127.0.0.2
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

configure_vms() {
    cd "${HOME}" || true
    for item in a b c
    do
        virsh destroy "${item}" 2>/dev/null || true
        virsh undefine "${item}" 2>/dev/null || true
    done

    # keep in sync with testbed-builder.sh
    ALPINE_SRC_URL="https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/cloud/alpine-3.23.6-x86_64-bios-tiny-r0.qcow2"
    ALPINE_TGT_FILE="${HOME}/$(basename "${ALPINE_SRC_URL}")"
    SRC_URL="${ALPINE_SRC_URL}"
    TGT_FILE="${ALPINE_TGT_FILE}"
    download

    qemu-img convert -O qcow2 -c -o compression_type=zstd "${TGT_FILE}" prototype.qcow2
    unset ALPINE_SRC_URL ALPINE_TGT_FILE SRC_URL TGT_FILE
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
            --channel unix,target.type=virtio,target.name=org.qemu.guest_agent.0 \
            --import --noautoconsole --noreboot
    done
}

configure_backup_dirs() {
    sudo mkdir -p /backup-vm/ /other_backup/
    sudo setfacl -d -R -m u:"${USER}":rwx /backup-vm/ /other_backup/
    sudo chown -R "${USER}":"${USER}" /backup-vm/ /other_backup/
}

tune_users_home() {
    cp -rT "${BASE_DIR}/home" "${HOME}"
}

closure() {
    set -e
    #set -x # Debug

    [ -f "${HOME}/configured" ] && printf '%s\n' "Already configured, exiting" && exit 0

    # Define BASE_DIR
    BASE_DIR="$(get_base_dir)"

    # Copy skeleton config before calling virsh
    tune_users_home

    DISTRO=arch
    if [ -e "/etc/os-release" ]
    then
        if grep -q "Debian" "/etc/os-release"
        then
            debian_privileged
        elif grep -q "Ubuntu" "/etc/os-release"
        then
            DISTRO=ubuntu
            ubuntu_privileged
        elif grep -q "AlmaLinux" "/etc/os-release"
        then
            DISTRO=alma
            rhel_privileged
        elif grep -q "RED " "/etc/os-release"
        then
            DISTRO=redos
            redos_privileged
        elif grep -q "Astra" "/etc/os-release"
        then
            DISTRO=astra
            astra_privileged
        elif grep -q "Fedora" "/etc/os-release"
        then
            DISTRO=fedora
            fedora_privileged
        elif grep -q "archlinux" "/etc/os-release"
        then
            DISTRO=arch
            arch_privileged
        elif grep -q "artixlinux" "/etc/os-release"
        then
            DISTRO=artix
            artix_privileged
        fi
    fi

    if [ -d /run/systemd/system ]
    then
      sudo systemctl enable --now xrdp qemu-guest-agent
    fi
    configure_libvirt
    configure_backup_dirs
    configure_vms
    configure_ssh

    touch "${HOME}/configured"
    #sudo poweroff
    unset DISTRO BASE_DIR
}

closure "${@}"
