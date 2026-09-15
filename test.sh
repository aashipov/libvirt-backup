#!/bin/sh

# ------------------------------------------------------------
#  test.sh – Semi-automated integration test
#
# Prepare a virtual machine called `unix`, unprivileged user called `user`, as per `HEADFUL.md`
# Craft a `/etc/hosts` synonym for `unix` IP
# Enable paswordless login `ssh-copy-id user@unix`, make sure it works (`ssh user@unix`), deploy the key to unix's /home/user/.ssh/
#
# The test target is configurable via the environment (defaults match the TEST.md test VM):
#   TEST_HOSTNAME  – remote host (e.g. an /etc/hosts synonym), default 'unix'
#   TEST_USERNAME  – unprivileged user at that host, default 'user'
#   TEST_APP_NAME  – remote directory for the project, default 'libvirt-backup'
#   TEST_REMOTE_HOME – remote home directory, default '/home/${TEST_USERNAME}'
# ------------------------------------------------------------

# ------------------------------------------------------------
# Script/base dir
# ------------------------------------------------------------
get_base_dir() {
    if [ -f "${0}" ]
    then
        # $0 points to a file on disk
        printf '%s\n' "$(cd -- "$(dirname -- "${0}")" && pwd)"
    else
        # The script was sourced in a shell where $0 is not the script path
        # Fallback to the current working directory
        printf '%s\n' "$(pwd)"
    fi
}

clean_leftovers() {
    find "${BACKUP_DIR}/" -type d -depth -mindepth 1 -exec rm -rf {} \;
    find "${ANOTHER_SERVER_ANOTHER_BACKUP_DIR}/" -type d -depth -mindepth 1 -exec rm -rf {} \;
}

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
    sleep 10
    virsh list --all
}

happy_path() {
    ./bc.sh
    ./rc.sh
}

stop_vms() {
    virsh resume c
    virsh destroy c
    virsh shutdown a
    sleep 10
    virsh list --all
}

display_result() {
    printf '%s\n' "${BACKUP_DIR:?}/ content"
    tree -ha "${BACKUP_DIR:?}/"

    printf '\n%s\n' "${ANOTHER_SERVER_ANOTHER_BACKUP_DIR:?}/ content"
    tree -ha "${ANOTHER_SERVER_ANOTHER_BACKUP_DIR:?}/"
}

# ------------------------------------------------------------
#  Main function to prevent occasional environment pollution
# ------------------------------------------------------------
closure() {
    set -e
    #set -x # Debug

    BASE_DIR="$(get_base_dir)"

    # Load library
    . "${BASE_DIR}/lib.sh"

    # Do the job
    cd "${BASE_DIR}"
    environment
    clean_leftovers
    start_vms
    happy_path
    stop_vms
    display_result
    unset BASE_DIR
}

closure
