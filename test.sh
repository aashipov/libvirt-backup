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
    rm -rf "${BACKUP_DIR}/"*
    rm -rf "${ANOTHER_SERVER_ANOTHER_BACKUP_DIR}/"*
}

launch_vms() {
    virsh start a
    virsh start c
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
    printf "/backup-vm/ content\n"
    tree -ha /backup-vm/

    printf "\n/other_backup/ content\n"
    tree -ha /other_backup/
}

# Main function
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
