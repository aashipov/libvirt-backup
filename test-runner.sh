#!/bin/sh

# ------------------------------------------------------------
#  test-runner.sh – Semi-automated integration test runner
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
    rsync --times --partial --recursive --delete --rsh="ssh -o BatchMode=yes" . "${TEST_HOSTNAME}:${TEST_REMOTE_HOME}/${TEST_APP_NAME}" || fail_internal "Failed to deploy source code"
}

# ------------------------------------------------------------
#  Main function to prevent occasional environment pollution
# ------------------------------------------------------------
closure() {
    set -e
    #set -x # Debug

    # Define BASE_DIR
    BASE_DIR="$(get_base_dir)"
    # Load library
    . "${BASE_DIR}/lib.sh"
    [ "${?}" -ne 0 ] && printf 'Could not load lib.sh, exiting' && exit 1

    # Do the job
    cd "${BASE_DIR}"
    check_dot_env_file
    environment
    ssh "${TEST_HOSTNAME}" "rm -rf ${TEST_APP_NAME}" || fail_internal "Failed to remove ${TEST_APP_NAME} via SSH"
    deploy_src
    ssh "${TEST_HOSTNAME}" "${TEST_APP_NAME}/debug.sh" || fail_internal "./debug.sh via SSH failed"
    ssh "${TEST_HOSTNAME}" "${TEST_APP_NAME}/test.sh" || fail_internal "./test.sh via SSH failed"
    unset BASE_DIR
}

closure
