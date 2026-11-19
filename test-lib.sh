#!/bin/sh

# ------------------------------------------------------------
#  lib.sh – Shared test functions
# ------------------------------------------------------------

# ------------------------------------------------------------
#  Prevent multiple loads of the library
# ------------------------------------------------------------
[ -n "${TEST_LIB_SH_LOADED}" ] && return
TEST_LIB_SH_LOADED=1
readonly TEST_LIB_SH_LOADED

# ------------------------------------------------------------
#  Global variables
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

BASE_DIR="$(get_base_dir)"

# ------------------------------------------------------------
#  Print to stderr and exit
#  Copy-pasteable between lib.sh and test-lib.sh
# ------------------------------------------------------------
fail_internal() {
    EXIT_CODE_TRAP=${?}
    [ "${EXIT_CODE_TRAP}" -eq 0 ] && EXIT_CODE_TRAP=1
    printf '%s\n' "${*}" >&2
    exit ${EXIT_CODE_TRAP}
    unset EXIT_CODE_TRAP
}

# ------------------------------------------------------------
#  Load environment from .env
#  Copy-pasteable between lib.sh and test-lib.sh
#  .env does not hold secrets or functions (a key-value store)
# ------------------------------------------------------------
load_dot_env_file() {
    # BASE_DIR is set up the call stack
    # Loads environment variables from .env
    ENV_FILE="${BASE_DIR}/.env"
    if [ ! -f "${ENV_FILE}" ]
    then
        fail_internal "No ${ENV_FILE} file found, craft one from ${ENV_FILE}.template"
    fi
    # Preflight .env check
    if ! LC_ALL=C awk '
      /^[[:space:]]*($|#)/ { next }
      !/^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=/ { exit 1 }
      /\$\(|`|;[[:space:]]*[^#]|&&|\|\|/ { exit 1 }
    ' "${ENV_FILE}"; then
      printf 'Unsafe or invalid syntax in %s\n' "${ENV_FILE}" >&2
      exit 1
    fi
    # allexport .env
    case "${-}" in
        *a*)
            HAD_A=1
            ;;
        *)
            HAD_A=0
            set -a
            ;;
    esac
    # source: not found workaround
    . "${ENV_FILE}"
    [ "${HAD_A}" -eq 0 ] && set +a
    # allexport .env
    unset ENV_FILE HAD_A
}

# ------------------------------------------------------------
# Check .env presence
# ------------------------------------------------------------
check_dot_env_file() {
    if [ ! -f "${BASE_DIR}/.env" ]
    then
        cp "${BASE_DIR}/.env.template" "${BASE_DIR}/.env"
    fi
    if ! grep -q '^TEST_HOSTNAME=' "${BASE_DIR}/.env"
    then
        printf '\n' >> .env
        cat "${BASE_DIR}/.test.env.template" >> "${BASE_DIR}/.env"
    fi
}

# ------------------------------------------------------------
# rsync cwd
# ------------------------------------------------------------
deploy_src() {
    scp -r "${BASE_DIR}" "${TEST_USERNAME}@${TEST_HOSTNAME}:${TEST_REMOTE_HOME}" || fail_internal "Failed to deploy source code"
}

# ------------------------------------------------------------
# Clean local dirs up
# ------------------------------------------------------------
clean_leftovers() {
    find "${BACKUP_DIR}/" -type d -depth -mindepth 1 -exec rm -rf {} \;
    find "${ANOTHER_SERVER_ANOTHER_BACKUP_DIR}/" -type d -depth -mindepth 1 -exec rm -rf {} \;
}

# ------------------------------------------------------------
# Happy path test related functions
# ------------------------------------------------------------
start_vm() {
    if ! virsh domstate "${1}" | grep -E -q "running|paused"
    then
        virsh start "${1}"
    fi
}

start_vms() {
    start_vm a
    start_vm c
    virsh suspend c
    sleep 30
    virsh list --all
}

backup_and_sync() {
    ./bc.sh
    ./rc.sh
}

stop_vms() {
    virsh resume c 2>/dev/null || true
    virsh destroy c 2>/dev/null || true
    virsh shutdown a 2>/dev/null || true
    sleep 30
    virsh list --all
}

display_result() {
    printf '%s\n' "${BACKUP_DIR:?}/ content"
    tree -ha "${BACKUP_DIR:?}/"

    printf '\n%s\n' "${ANOTHER_SERVER_ANOTHER_BACKUP_DIR:?}/ content"
    tree -ha "${ANOTHER_SERVER_ANOTHER_BACKUP_DIR:?}/"
}

happy_path() {
    clean_leftovers
    start_vms
    backup_and_sync
    stop_vms
    display_result
}

# ------------------------------------------------------------
# Testbed rapid deployment
# ------------------------------------------------------------
remove_vm() {
    if virsh list --all | grep -q "\b${TARGET_VM_NAME}\b"
    then
        if virsh list --name --state-running | grep -q "${TARGET_VM_NAME}"
        then
            virsh destroy "${TARGET_VM_NAME}" || fail_internal "Failed to destroy ${TARGET_VM_NAME}"
        fi
        while virsh list --name --state-running | grep -q "\b${TARGET_VM_NAME}\b"
        do
            printf '%s is still running. Waiting...\n' "${TARGET_VM_NAME}"
            sleep 5
        done
        printf '%s has shut down.\n' "${TARGET_VM_NAME}"
        virsh undefine "${TARGET_VM_NAME}" || fail_internal "Failed to undefine ${TARGET_VM_NAME}"
        rm -rf "${TARGET_DISK_FILE}"
    fi
}

build_disk() {
    if [ ! -f "${TARGET_DISK_FILE}" ]
    then
        qemu-img convert -O qcow2 -o compression_type=zstd -c "${TGT_FILE}" "${TARGET_DISK_FILE}" || fail_internal "Failed to convert ${TGT_FILE} to ${TARGET_DISK_FILE}"
        qemu-img resize "${TARGET_DISK_FILE}" "${TESTBED_DISK_CAPACITY}" || fail_internal "Failed to resize ${TARGET_DISK_FILE} to ${TESTBED_DISK_CAPACITY}"
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
            fail_internal "Failed to download ${SRC_URL}"
        fi
        mv "${TGT_FILE}.part" "${TGT_FILE}"
    fi

    if ! qemu-img check "${TGT_FILE}" > /dev/null 2>&1
    then
        fail_internal "Bad file ${TGT_FILE}: remove and re-run"
    fi
}

download_archxfs() {
    SRC_URL="${ARCHXFS_SRC_URL}"
    TGT_FILE="${ARCHXFS_TGT_FILE}"
    download
}

# ------------------------------------------------------------
# Testbed rapid deployment
# ------------------------------------------------------------

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

    if [ "${DISTRO}" = "debian" ] || [ "${DISTRO}" = "astra" ] || [ "${DISTRO}" = "arch" ] || [ "${DISTRO}" = "artix" ] || [ "${DISTRO}" = "alpine" ]
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
    sudo dnf -y install xorg-x11-server-Xorg virt-manager xrdp xorgxrdp openbox chromium firefox thunar xfce4-terminal xfce4-taskmanager mousepad dbus-daemon gvfs gvfs-smb weston dmenu gnome-themes-extra adwaita-icon-theme
    sudo dnf -y remove cloud-init
    sudo dnf -y clean all
    sudo systemctl enable --now crond
}

redos_privileged() {
    sudo dnf -y upgrade
    sudo dnf -y install cronie git rsync acl sudo qemu-kvm libvirt virt-install mc tree curl qemu-guest-agent
    sudo dnf -y install xorg-x11-server-Xorg virt-manager xrdp xorgxrdp openbox chromium firefox thunar xfce4-terminal xfce4-taskmanager mousepad dbus-daemon gvfs gvfs-smb weston dmenu gnome-themes-extra adwaita-icon-theme
    sudo dnf -y clean all
    sudo systemctl enable --now crond
}

fedora_privileged() {
    sudo dnf -y upgrade
    sudo dnf -y config-manager disable fedora-cisco-openh264
    sudo dnf -y install cronie git rsync acl sudo qemu-kvm libvirt virt-install mc tree curl qemu-guest-agent
    sudo dnf -y install xorg-x11-server-Xorg virt-manager xrdp xorgxrdp openbox chromium firefox thunar xfce4-terminal xfce4-taskmanager mousepad dbus-daemon gvfs gvfs-smb weston dmenu adwaita-icon-theme adwaita-icon-theme-legacy
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
    sudo apt-get install -y virt-manager weston winpr3-utils xrdp xorgxrdp openbox chromium firefox-esr thunar xfce4-terminal xfce4-taskmanager mousepad gvfs gvfs-backends suckless-tools gnome-themes-extra adwaita-icon-theme
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
    sudo apt-get install -y virt-manager weston winpr-utils xrdp xorgxrdp openbox thunar xfce4-terminal xfce4-taskmanager mousepad gvfs gvfs-backends dmenu gnome-themes-extra adwaita-icon-theme
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
    sudo apt-get install -y virt-manager weston winpr-utils xrdp xorgxrdp openbox chromium firefox gvfs gvfs-backends mate-terminal nautilus geany gvfs gvfs-backends gnome-themes-extra adwaita-icon-theme #suckless-tools
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
    # dmenu
    if [ ! -e "${HOME}/src/dmenu/" ]
    then
        sudo apt install build-essential libx11-dev libxinerama-dev libxft-dev
        mkdir -p "${HOME}/src/"
        cd "${HOME}/src/"
        git clone git://git.suckless.org/dmenu
        cd "${HOME}/src/dmenu/"
        make
        sudo make install
    fi
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

alpine_privileged() {
    doas apk update
    doas apk upgrade
    doas apk add sudo cronie git rsync acl qemu-system-x86_64 qemu-ui-gtk qemu-audio-pa libvirt-daemon libvirt-client tree curl mc openssh qemu-guest-agent networkmanager networkmanager-cli vim dnsmasq qemu-img virt-install openssl
    doas apk add weston weston-backend-drm weston-backend-wayland weston-shell-desktop freerdp openbox chromium firefox thunar xfce4-terminal xfce4-taskmanager mousepad gvfs gvfs-smb dmenu xrdp xorgxrdp dbus polkit fontconfig font-liberation font-dejavu #font-noto
    if [ ! -e /etc/xrdp/key.pem ] && [ ! -e /etc/xrdp/cert.pem ]
    then
        doas openssl req -x509 -newkey rsa:2048 -nodes -keyout /etc/xrdp/key.pem -out /etc/xrdp/cert.pem -days 365 -subj "/CN=$(hostname)"
        doas chmod 640 /etc/xrdp/key.pem
        doas chmod 644 /etc/xrdp/cert.pem
    fi
    doas setup-xorg-base
    doas rc-service xrdp start
    doas rc-service xrdp-sesman start
    doas rc-update add xrdp
    doas rc-update add xrdp-sesman
    doas rc-service dbus start
    doas rc-update add dbus default
    doas rc-service polkit start
    doas rc-update add polkit default
    doas rc-service libvirtd start
    doas rc-update add libvirtd default
    doas apk del cloud-init
    doas apk add --no-cache shadow
    doas fc-cache -fv
}

# ------------------------------------------------------------
#  Generates per-testbed SSH key pair, adjusts config
# ------------------------------------------------------------
configure_testbed_ssh() {
    mkdir -p "${BASE_DIR}/home/.ssh" || fail_internal "Failed to create ${BASE_DIR}/home/.ssh directory"
    if [ ! -e "${BASE_DIR}/home/.ssh/id_rsa" ]
    then
        chmod 700 "${BASE_DIR}/home/.ssh"
        ssh-keygen -t rsa -b 4096 -N "" -C "dummy@dummy.org" -f "${BASE_DIR}/home/.ssh/id_rsa"
        chmod 0600 "${BASE_DIR}/home/.ssh/id_rsa"
    fi
    mkdir -p "${HOME}/.ssh/${TEST_HOSTNAME}" || fail_internal "Failed to create ${HOME}/.ssh/${TEST_HOSTNAME} directory"
    cp "${BASE_DIR}/home/.ssh/id_rsa" "${HOME}/.ssh/${TEST_HOSTNAME}"
    cp "${BASE_DIR}/home/.ssh/id_rsa.pub" "${HOME}/.ssh/${TEST_HOSTNAME}"
    if [ ! -e "${HOME}/.ssh/config" ] || ! grep -q "${TEST_HOSTNAME}" "${HOME}/.ssh/config"
    then
cat << EOF >> "${HOME}/.ssh/config"
Host ${TEST_HOSTNAME}
    HostName ${TEST_HOSTNAME}
    User admin
    IdentityFile ~/.ssh/${TEST_HOSTNAME}/id_rsa
    IdentitiesOnly yes
EOF
    fi
}

# ------------------------------------------------------------
#  Generates per-VM SSH key pair
#  If configure_testbed_ssh is not possible (e.g., non-Linux host)
# ------------------------------------------------------------
configure_vm_ssh() {
    mkdir -p "${HOME}/.ssh"
    if [ ! -f "${HOME}/.ssh/id_rsa" ]
    then
        ssh-keygen -t rsa -b 4096 -N "" -C "dummy@dummy.org" -f "${HOME}/.ssh/id_rsa"
        chmod 0600 "${HOME}/.ssh/id_rsa"
        printf '%s\n' "From host, copy guest ssh pair out:"
        printf '%s\n' "scp admin@${DISTRO}-builder:/home/admin/.ssh/id_rsa{,.pub} ~/.ssh/unix/ && chmod 0600 ~/.ssh/unix/id_rsa"
    fi
    ssh-copy-id 127.0.0.2
}

configure_nested_vms() {
    cd "${HOME}" || true
    for item in a b c
    do
        virsh destroy "${item}" 2>/dev/null || true
        virsh undefine "${item}" 2>/dev/null || true
    done

    # keep in sync with testbed-builder.sh
    ARCHXFS_TGT_FILE="${HOME}/$(basename "${ARCHXFS_SRC_URL}")"
    SRC_URL="${ARCHXFS_SRC_URL}"
    TGT_FILE="${ARCHXFS_TGT_FILE}"
    download

    qemu-img convert -O qcow2 -c -o compression_type=zstd "${TGT_FILE}" prototype.qcow2
    qemu-img create -f qcow2 -o compression_type=zstd blank-prototype.qcow2 256M

    for item in a b c; do
      sudo cp prototype.qcow2 /var/lib/libvirt/images/"$item".qcow2
      sudo cp blank-prototype.qcow2 /var/lib/libvirt/images/"$item$item".qcow2
    done

    rm "${TGT_FILE}" prototype.qcow2 blank-prototype.qcow2
    unset ARCHXFS_SRC_URL ARCHXFS_TGT_FILE SRC_URL TGT_FILE

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

# ------------------------------------------------------------
#  Yes/No dialog, default No
# ------------------------------------------------------------
yes_no_dialog() {
    while true; do
        printf "%s [y/N]: " "${1:-Are you sure?}"
        read -r reply
        case "$reply" in
            [yY]|[yY][eE][sS]) return 0 ;;
            [nN]|[nN][oO]|"") return 1 ;;
            *) printf "Please answer yes or no.\n" ;;
        esac
    done
}
