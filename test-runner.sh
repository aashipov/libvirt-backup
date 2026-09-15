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

# ------------------------------------------------------------
# Check .env presence
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

# ------------------------------------------------------------
# rsync cwd
# ------------------------------------------------------------
deploy_src() {
    rsync --times --partial --recursive --delete --rsh="ssh -o BatchMode=yes" "${BASE_DIR}" "${TEST_HOSTNAME}:${TEST_REMOTE_HOME}/${TEST_APP_NAME}" || fail_internal "Failed to deploy source code"
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
    check_dot_env_file
    environment
    deploy_src
    ssh "${TEST_HOSTNAME}" "${TEST_APP_NAME}/debug.sh" || fail_internal "./debug.sh via SSH failed"
    ssh "${TEST_HOSTNAME}" "${TEST_APP_NAME}/test.sh" || fail_internal "./test.sh via SSH failed"
    unset BASE_DIR
}

closure
