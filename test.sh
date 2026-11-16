#!/bin/sh

# ------------------------------------------------------------
#  test.sh – Semi-automated integration test
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

    printf '\nQEMU_IMG_CONVERT_WITH_COMPRESSION=0\n' >> "${BASE_DIR}/.env"
    environment
    log "QEMU_IMG_CONVERT_WITH_COMPRESSION=0"
    happy_path

    printf '\nQEMU_IMG_CONVERT_WITH_COMPRESSION=1\n' >> "${BASE_DIR}/.env"
    environment
    log "QEMU_IMG_CONVERT_WITH_COMPRESSION=1"
    happy_path

    unset BASE_DIR
}

closure
