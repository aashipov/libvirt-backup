#!/bin/sh

# ------------------------------------------------------------
# testbed-configurator.sh – Post-cloud-init configurator, as unprivileged admin
#
# cloud-init does not handle complex configuration well, it's simpler than ansible though.
# It handles default user creation well.
# This script performs post cloud-init prototype configuration, suits non-cloud-init VM/baremetal as well.
# Not intended to import lib.sh (test-lib.sh only)
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

closure() {
    set -e
    #set -x # Debug

    [ -f "${HOME}/configured" ] && printf '%s\n' "Already configured, exiting" && exit 0

    # Define BASE_DIR
    BASE_DIR="$(get_base_dir)"
    # Load test library
    TEST_LIB_SH="${BASE_DIR}/test-lib.sh"
    if [ ! -e "${TEST_LIB_SH}" ]
    then
        printf '%s does not exist, exiting\n' "${TEST_LIB_SH}"
        exit 1
    fi
    # shellcheck source=test-lib.sh
    if ! . "${TEST_LIB_SH}"
    then
        printf 'Could not load %s, exiting\n' "${TEST_LIB_SH}"
        exit 1
    fi
    unset TEST_LIB_SH

    # Do the job
    load_dot_env_file

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
        elif grep -q "alpinelinux" "/etc/os-release"
        then
            DISTRO=alpine
            alpine_privileged
        fi
    fi

    if [ -d /run/systemd/system ]
    then
      sudo systemctl enable --now xrdp qemu-guest-agent
    fi
    configure_libvirt
    configure_backup_dirs
    configure_nested_vms
    configure_vm_ssh
    touch "${HOME}/configured"
    
    unset DISTRO BASE_DIR
}

closure "${@}"
