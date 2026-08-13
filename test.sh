#!/bin/sh

# ------------------------------------------------------------
#  test.sh – Semi-automated integration test
#
# Prepare a virtual machine called `unix`, unprivileged user called `user`, as per `HEADFUL.md`
# Craft a `/etc/hosts` synonym for `unix` IP
# Enable paswordless login `ssh-copy-id user@unix`, make sure it works (`ssh user@unix`), deploy the key to unix's /home/user/.ssh/
# ------------------------------------------------------------

_fail() {
    printf '%s\n' "${@}"
    exit 1
}

execute_function_via_ssh() {
    local FUNCTION_NAME="${1}"
    ssh "${USERNAME}@${HOSTNAME}" "$(typeset -f); ${FUNCTION_NAME}" || _fail "Failed to call ${FUNCTION_NAME} via SSH"
}

check_dot_env_file() {
    if [ ! -f ".env" ]
    then
        cp .env.template .env
    fi
}

deploy_src() {
    local APP_NAME="libvirt-backup"
    rsync --times --partial --recursive --delete --rsh="ssh -o BatchMode=yes" . "${USERNAME}@${HOSTNAME}:/home/user/${APP_NAME}" || _fail "Failed to deploy source code"
}

clean_leftovers() {
    rm -rf /backup-vm/* /other_backup/*
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
    printf "/backup-vm/ content\n"
    ls -R /backup-vm/

    printf "\n/other_backup/ content\n"
    ls -R /other_backup/
}

# Main function
closure() {
    set -e
    #set -x # Debug
    local HOSTNAME="unix" # Host to perform tests with
    local USERNAME="user" # Unprivileged user at that host
    local APP_NAME="libvirt-backup" # A dir for https://github.com/aashipov/libvirt-backup.git clone

    check_dot_env_file
    deploy_src
    ssh "${USERNAME}@${HOSTNAME}" "${APP_NAME}/debug.sh" || _fail ".env file check via SSH failed"
    execute_function_via_ssh "clean_leftovers"
    execute_function_via_ssh "launch_nested_vms"
    execute_function_via_ssh "happy_path"
    execute_function_via_ssh "turn_off_vms"
    execute_function_via_ssh "display_result"
}

closure
