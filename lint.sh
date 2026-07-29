#!/bin/bash

# ------------------------------------------------------------
#  lint.sh – Lints Shell Scripts in the project
# ------------------------------------------------------------
# NOTE:
#     Install & setup zsh ksh bash dash sh first

# ------------------------------------------------------------
#  Main function to prevent occasional environment pollution
# ------------------------------------------------------------
closure() {
    #set -x # debug

    # Load library
    local _SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$0")")
    local _LIB_SH_FILE="${_SCRIPT_DIR}/lib.sh"
    if [ ! -f "${_LIB_SH_FILE}" ]
    then
        printf '%s is missing. Exiting\n' "${_LIB_SH_FILE}"
        exit 1
    fi
    . "${_LIB_SH_FILE}"

    # Do the job
    environment
    for file in "${_SCRIPT_DIR}"/*.sh; do
        printf 'Lint %s start\n' "${file}"
        lint_shell_script "${file}"
        printf 'Lint %s finish\n' "${file}"
    done
}

closure
