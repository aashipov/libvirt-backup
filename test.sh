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

_fail() {
    printf '%s\n' "${@}"
    exit 1
}

execute_function_via_ssh() {
    local FUNCTION_NAME="${1}"
    ssh "${TEST_USERNAME}@${TEST_HOSTNAME}" "$(typeset -f); TEST_APP_NAME='${TEST_APP_NAME}'; ${FUNCTION_NAME}" || _fail "Failed to call ${FUNCTION_NAME} via SSH"
}

check_dot_env_file() {
    if [ ! -f ".env" ]
    then
        cp .env.template .env
    fi
}

deploy_src() {
    rsync --times --partial --recursive --delete --rsh="ssh -o BatchMode=yes" . "${TEST_USERNAME}@${TEST_HOSTNAME}:${TEST_REMOTE_HOME}/${TEST_APP_NAME}" || _fail "Failed to deploy source code"
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
    cd "${TEST_APP_NAME}"
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
    check_dot_env_file
    environment
    deploy_src
    ssh "${TEST_USERNAME}@${TEST_HOSTNAME}" "${TEST_APP_NAME}/debug.sh" || _fail "./debug.sh via SSH failed"
    execute_function_via_ssh "clean_leftovers"
    execute_function_via_ssh "launch_nested_vms"
    execute_function_via_ssh "happy_path"
    execute_function_via_ssh "turn_off_vms"
    execute_function_via_ssh "display_result"
}

closure
