#!/bin/sh

# ------------------------------------------------------------
#  test-runner.sh – Semi-automated integration test runner
#  Deploys source tree to VM /home/${TEST_USERNAME}/, launches `test.sh` via SSH
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

check_dot_env_file() {
    if [ ! -f ".env" ]
    then
        cp .env.template .env
    fi
    if ! grep -q 'TEST_' ".env"
    then
        printf "\n" >> .env
        cat .test.env.template >> .env
    fi
}

deploy_src() {
    rsync --times --partial --recursive --delete --rsh="ssh -o BatchMode=yes" --exclude='.env' --exclude='.git/' . "${TEST_USERNAME}@${TEST_HOSTNAME}:${TEST_REMOTE_HOME}/${TEST_APP_NAME}" || _fail "Failed to deploy source code"
}

# Main function
closure() {
    set -e
    #set -x # Debug

    # Load library
    . "$(dirname -- "$(readlink -f -- "$0")")/lib.sh"

    # Do the job
    cd "$(dirname -- "$(readlink -f -- "$0")")"
    check_dot_env_file
    environment
    deploy_src
    ssh "${TEST_USERNAME}@${TEST_HOSTNAME}" "${TEST_APP_NAME}/debug.sh" || _fail "./debug.sh via SSH failed"
    ssh "${TEST_USERNAME}@${TEST_HOSTNAME}" "${TEST_APP_NAME}/test.sh" || _fail "./test.sh via SSH failed"
}

closure
