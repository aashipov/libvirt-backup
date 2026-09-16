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
        printf '%s\n' "$(cd -- "$(dirname -- "${0}")" && pwd)"
    else
        # The script was sourced in a shell where $0 is not the script path
        # Fallback to the current working directory
        printf '%s\n' "$(pwd)"
    fi
}

clean_leftovers() {
    find "${BACKUP_DIR}/" -type d -depth -mindepth 1 -exec rm -rf {} \;
    find "${ANOTHER_SERVER_ANOTHER_BACKUP_DIR}/" -type d -depth -mindepth 1 -exec rm -rf {} \;
}

start_vm() {
    if ! virsh domstate "${1}" | grep -E -q "running|paused"
    then
        virsh start "${1}"
    fi
}

start_vms() {
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

stop_vms() {
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

    # Define BASE_DIR
    BASE_DIR="$(get_base_dir)"
    # Load library
    . "${BASE_DIR}/lib.sh"
    [ "${?}" -ne 0 ] && printf 'Could not load lib.sh, exiting' && exit 1

    # Do the job
    cd "${BASE_DIR}"
    environment
    clean_leftovers
    start_vms
    happy_path
    stop_vms
    display_result
    unset BASE_DIR
}

closure
