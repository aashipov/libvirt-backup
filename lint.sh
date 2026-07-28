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
    local _SCRIPT_DIR=$(dirname -- $(readlink -f -- "$0") | cd | pwd)
    local _LIB_SH_FILE=${_SCRIPT_DIR}/lib.sh
    if [ ! -f ${_LIB_SH_FILE} ]
    then
        printf "${_LIB_SH_FILE} is missing. Exiting"
        exit 1
    fi
    . ${_LIB_SH_FILE}

    # Do the job
    for file in ${_SCRIPT_DIR}/*.sh; do
        printf "Lint ${file} start\n"
        lint_shell_script ${file}
        printf "Lint ${file} finish\n\n"
    done
}

closure
