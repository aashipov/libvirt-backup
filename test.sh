#!/bin/sh

# ------------------------------------------------------------
#  test.sh – Semi-automated integration test
#
# Prepare a virtual machine called `unix`, unprivileged user called `user`, as per `HEADFUL.md`
# Craft a `/etc/hosts` synonym for `unix` IP
# Enable paswordless login `ssh-copy-id user@unix`, make sure it works (`ssh user@unix`)
# ------------------------------------------------------------

execute_via_ssh() {
    local FUNCTION_NAME="${1}"
    ssh "${USERNAME}@${HOSTNAME}" "$(typeset -f); ${FUNCTION_NAME}"
}

update_repo_clone() {
    local APP_NAME="libvirt-backup"
    if [ ! -d "${APP_NAME}" ]
    then
        git clone https://github.com/aashipov/libvirt-backup.git
        cd "${APP_NAME}"
        cp .env.template .env
    else
        cd "${APP_NAME}"
        git pull -r
    fi
}

clean_leftovers() {
    rm -rf /backupv-vm/* /other_backup/*
}

launch_nested_vms() {
    virsh start a
    virsh start c
    virsh suspend c
    sleep 10
    virsh list --all
}

happy_path() {
    local APP_NAME="libvirt-backup"
    cd "${APP_NAME}"
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
    ls -lA /backup-vm/*/a/
    ls -lA /backup-vm/*/b/
    ls -lA /other_backup/*/a/
    ls -lA /other_backup/*/b/
}

# Main function
closure() {
    #set -x # Debug
    local HOSTNAME="unix" # Host to perform tests with
    local USERNAME="user" # Unprivileged user at that host
    local APP_NAME="libvirt-backup" # A dir for https://github.com/aashipov/libvirt-backup.git clone

    execute_via_ssh "update_repo_clone"
    execute_via_ssh "clean_leftovers"
    execute_via_ssh "launch_nested_vms"
    execute_via_ssh "happy_path"
    execute_via_ssh "turn_off_vms"
    execute_via_ssh "display_result"
}

closure
