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

clean_leftovers() {
    find "${BACKUP_DIR}/" -type d -depth -mindepth 1 -exec rm -rf {} \;
    find "${ANOTHER_SERVER_ANOTHER_BACKUP_DIR}/" -type d -depth -mindepth 1 -exec rm -rf {} \;
}

start_vm() {
    local _VM_NAME="${1}"
    if ! virsh domstate "${_VM_NAME}" | grep -E -q "running|paused"
    then
        virsh start "${_VM_NAME}"
    fi
}

launch_vms() {
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

turn_off_vms() {
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

    # Load library
    . "$(dirname -- "$(readlink -f -- "$0")")/lib.sh"

    # Do the job
    cd "$(dirname -- "$(readlink -f -- "$0")")"
    environment
    clean_leftovers
    launch_vms
    happy_path
    turn_off_vms
    display_result
}

closure
