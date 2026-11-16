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
        printf '%s\n' "$(cd -- "$(dirname -- "${0}")" && pwd -P)"
    else
        # The script was sourced in a shell where $0 is not the script path
        # Fallback to the current working directory
        printf '%s\n' "$(pwd -P)"
    fi
}

# ------------------------------------------------------------
#  Main function to prevent occasional environment pollution
# ------------------------------------------------------------
closure() {
    set -e
    #set -x # debug

    # Define BASE_DIR
    BASE_DIR="$(get_base_dir)"
    # Load libraries
    LIB_NAMES="lib.sh test-lib.sh"
    for LIB_NAME in ${LIB_NAMES}
    do
        if [ ! -e "${BASE_DIR}/${LIB_NAME}" ]
        then
            printf '%s does not exist, exiting\n' "${BASE_DIR}/${LIB_NAME}"
            exit 1
        fi
        # shellcheck source=lib.sh
        if ! . "${BASE_DIR}/${LIB_NAME}"
        then
            printf 'Could not load %s, exiting\n' "${BASE_DIR}/${LIB_NAME}"
            exit 1
        fi
    done
    unset LIB_NAMES

    # Do the job
    cd "${BASE_DIR}"
    check_dot_env_file
    environment
    check_mandatory_variables_set ".test.env.template"
    if ! printf '%s\n' "${TEST_APP_NAME}" | grep -qE '^[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz][ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-]+$'
    then
        fail_internal "TEST_APP_NAME contains unsafe characters ${TEST_APP_NAME} — only latin letters and '-' are allowed"
    fi
    ssh "${TEST_USERNAME}@${TEST_HOSTNAME}" "rm -rf ${TEST_REMOTE_HOME}/${TEST_APP_NAME}" || fail_internal "Failed to remove ${TEST_REMOTE_HOME}/${TEST_APP_NAME} via SSH"
    deploy_src
    ssh "${TEST_USERNAME}@${TEST_HOSTNAME}" "${TEST_REMOTE_HOME}/${TEST_APP_NAME}/debug.sh" || fail_internal "${TEST_REMOTE_HOME}/${TEST_APP_NAME}/debug.sh via SSH failed"
    ssh "${TEST_USERNAME}@${TEST_HOSTNAME}" "${TEST_REMOTE_HOME}/${TEST_APP_NAME}/test.sh" || fail_internal "${TEST_REMOTE_HOME}/${TEST_APP_NAME}/test.sh via SSH failed"
    unset BASE_DIR
}

closure
