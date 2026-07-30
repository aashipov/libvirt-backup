#!/bin/bash

# ------------------------------------------------------------
#  lib.sh – Shared functions
# ------------------------------------------------------------

# ------------------------------------------------------------
#  Prevent multiple loads of the library
# ------------------------------------------------------------
if [ -n "${_LIB_SH_LOADED}" ]
then
    return
fi
readonly _LIB_SH_LOADED=1

# ------------------------------------------------------------
#  Utility helpers
# ------------------------------------------------------------

_log() {
    printf '%s - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${1}" | tee -a "${BACKUP_LOG_FILE}"
}

log() {
    _log "${1}"
}

die() {
    _log "${1}"
    exit 1
}

# ------------------------------------------------------------
#  Check if all of the mandatory variables are set in the environment
# ------------------------------------------------------------
check_mandatory_variables_set() {
    # .env.template is a single source of truth about mandatory variables
    local MANDATORY_VARIABLES_NAMES="$(cat "${_SCRIPT_DIR}/.env.template" | grep -v '^#' | grep -v '^$' | awk -F'=' '{print $1}')"
    for VAR_PTR in ${MANDATORY_VARIABLES_NAMES}
    do
        if [ ! -n "${!VAR_PTR}" ]
        then
            die "Mandatory variable ${VAR_PTR} is not defined or blank"
        else
            readonly "${VAR_PTR}"
        fi
    done
}

# ------------------------------------------------------------
#  Environment loading
# ------------------------------------------------------------
environment() {
    block_root
    # Loads environment variables from .env
    local ENV_FILE="${_SCRIPT_DIR}/.env"
    if [ ! -f "${ENV_FILE}" ]
    then
        die "No ${ENV_FILE} file found, craft one from ${ENV_FILE}.template"
    fi
    # . for bash, zsh, ksh, (d)ash. source for (t)csh
    . "${ENV_FILE}"
    check_mandatory_variables_set
}

create_backup_dir() {
    # Creates a local backup dir if missing
    mkdir -p "${BACKUP_DIR}" "${ANOTHER_SERVER_ANOTHER_BACKUP_DIR}"
}

create_current_backup_dir() {
    # Creates a ${BACKUP_DIR}/YYYY-mm-dd for the current run of the script
    mkdir -p "${CURRENT_BACKUP_DIR}"
}

# ------------------------------------------------------------
#  Marker/lock file
# ------------------------------------------------------------
check_running() {
    # if marker/lock file ${RUNNING_FILE} exists
    if [ -f "${RUNNING_FILE}" ]
    then
        die "Another copy of this file may be running. Stop it, remove ${RUNNING_FILE} and repeat. Exiting"
    fi
}

create_running() {
    # creates a marker/lock file ${RUNNING_FILE}
    touch "${RUNNING_FILE}"
}

rm_running() {
    # removes the marker/lock file ${RUNNING_FILE}
    rm -f "${RUNNING_FILE}"
}

# ------------------------------------------------------------
#  Pipe (|) separated VM disk list
# ------------------------------------------------------------
get_vm_disk_names_and_absolute_paths() {
    # Extract disk name | absolute path to disk file
    local _VM_NAME="${1}"
    local DOMBLKLIST="$(virsh domblklist --details "${_VM_NAME}" | grep disk)" || die "Could not parse disk list for ${_VM_NAME}"
    local DISK_FILES=$(printf "%s\n" "${DOMBLKLIST}" | awk '{print $3 "|" $4}')
    printf "%s\n" "${DISK_FILES}"
}

# ------------------------------------------------------------
#  Back the running VM up
# ------------------------------------------------------------
backup_vm() {
    # Exports VM configuration (XML) and copies disks
    local VM_NAME="${1}"
    log "${VM_NAME} backup start"

    # Per-VM dir in the ${CURRENT_BACKUP_DIR}
    local VM_BACKUP_DIR="${CURRENT_BACKUP_DIR}/${VM_NAME}"
    mkdir -p "${VM_BACKUP_DIR}"

    # Collect VM disk file paths to PSV file
    local VM_DISKS_FILE="${VM_BACKUP_DIR}/disks.psv"
    get_vm_disk_names_and_absolute_paths "${VM_NAME}" > "${VM_DISKS_FILE}"

    # Dump VM config
    virsh dumpxml "${VM_NAME}" > "${VM_BACKUP_DIR}/${VM_NAME}.xml" || die "Failed to dump an XML config for ${VM_NAME}"

    # Backup job descriptor content (running VMs only)
    local BACKUP_JOB_DESCRIPTOR_CONTENT="<domainbackup>\n    <disks>"
    while IFS= read -r line; do
        local DISK_NAME=$(printf "%s\n" "${line}" | awk -F'|' '{print $1}')
        local DISK_FILE_ABSOLUTE_PATH=$(printf "%s\n" "${line}" | awk -F'|' '{print $2}')
        local DISK_FILE_NAME
        DISK_FILE_NAME="$(basename "${DISK_FILE_ABSOLUTE_PATH}")"
        local TARGET_DISK_FILE_ABSOLUTE_PATH="${VM_BACKUP_DIR}/${DISK_FILE_NAME}"

        if virsh domstate "${VM_NAME}" | grep -q "running"
        then
            # Workaround target file permissions
            local TARGET_DISK_CAPACITY
            TARGET_DISK_CAPACITY="$(virsh domblkinfo "${VM_NAME}" "${DISK_NAME}" | grep Capacity | awk '{print $2}')"
            qemu-img create -f qcow2 "${TARGET_DISK_FILE_ABSOLUTE_PATH}" "${TARGET_DISK_CAPACITY}" || die "Failed to create a target file for ${TARGET_DISK_FILE_ABSOLUTE_PATH}"

            BACKUP_JOB_DESCRIPTOR_CONTENT="${BACKUP_JOB_DESCRIPTOR_CONTENT}\n        <disk name='${DISK_NAME}' type='file'>\n            <target file='${TARGET_DISK_FILE_ABSOLUTE_PATH}'/>\n                <driver type='qcow2'/>\n        </disk>\n"
        else
            # copy offline VM file
            # qemu-img convert -O qcow2 -c ${DISK_FILE_ABSOLUTE_PATH} ${TARGET_DISK_FILE_ABSOLUTE_PATH} || die "Copy of ${DISK_FILE_ABSOLUTE_PATH} ${TARGET_DISK_FILE_ABSOLUTE_PATH} failed"
            cp -p "${DISK_FILE_ABSOLUTE_PATH}" "${VM_BACKUP_DIR}/"
        fi
    done < "${VM_DISKS_FILE}"
    BACKUP_JOB_DESCRIPTOR_CONTENT="${BACKUP_JOB_DESCRIPTOR_CONTENT}    </disks>\n</domainbackup>"

    # Running VM only: persist backup task xml to a file
    if virsh domstate "${VM_NAME}" | grep -q "running"
    then
        local BACKUP_TASK_FILE="${VM_BACKUP_DIR}/${VM_NAME}-backup-job-descriptor.xml"
        # printf "%s\n" "${BACKUP_JOB_DESCRIPTOR_CONTENT}" would produce an unparseable XML
        printf "${BACKUP_JOB_DESCRIPTOR_CONTENT}\n" > "${BACKUP_TASK_FILE}"
        # launch backup
        virsh backup-begin "${VM_NAME}" --reuse-external --backupxml "${BACKUP_TASK_FILE}" ||
                die "Failed to start backup for ${VM_NAME}"

        # wait completion
        while :; do
            if virsh domjobinfo "${VM_NAME}" | grep -q "None"
            then
                break
            fi
            sleep 10s
        done
    fi
    log "${VM_NAME} backup finish"
}

# ------------------------------------------------------------
#  Back the VMs up
# ------------------------------------------------------------
backup_vms() {
    log "Backup start"
    for VM_NAME_TO_BACK_UP in ${VM_NAMES_TO_BACK_UP}
    do
        backup_vm "${VM_NAME_TO_BACK_UP}"
    done
    log "Backup finish"
}

# ------------------------------------------------------------
#  Kill the the backup jobs
# ------------------------------------------------------------
kill_backup_jobs() {
    log "Kill backup jobs start"
    for VM_NAME_TO_BACK_UP in ${VM_NAMES_TO_BACK_UP}
    do
        if virsh domstate "${VM_NAME_TO_BACK_UP}" | grep -q "running"
        then
           virsh domjobabort "${VM_NAME_TO_BACK_UP}"
           log "${VM_NAME_TO_BACK_UP} backup job killed"
        else
            log "${VM_NAME_TO_BACK_UP} is not running, skipping"
        fi
    done
    log "Kill backup jobs finish"
}

# ------------------------------------------------------------
#  Trap handler — aborts backup jobs and removes lock on SIGINT/SIGTERM
# ------------------------------------------------------------
cleanup_on_exit() {
    kill_backup_jobs
    rm_running
    exit 1
}

# ------------------------------------------------------------
#  Removes obsolete backups
# ------------------------------------------------------------
clean_obsolete_backups() {
    log "Clean obsolete backups start"
    if [ -d "${ANOTHER_SERVER_ANOTHER_BACKUP_DIR}" ]
    then
        find "${ANOTHER_SERVER_ANOTHER_BACKUP_DIR}/" -depth -mindepth 1 -mtime "${DAYS_TO_KEEP_BACKUPS}" -exec rm -rf {} \;
    fi

    if [ -d "${BACKUP_DIR}" ]
    then
        find "${BACKUP_DIR}/" -depth -mindepth 1 -mtime "${DAYS_TO_KEEP_BACKUPS}" -exec rm -rf {} \;
    fi
    log "Clean obsolete backups finish"
}

# ------------------------------------------------------------
#  Pushes backups to remote server
# ------------------------------------------------------------
push_backups_to_another_server() {
    log "Push ${BACKUP_DIR} to ${ANOTHER_SERVER_IP}:${ANOTHER_SERVER_ANOTHER_BACKUP_DIR} start"
    rsync -avz -e "ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new" "${BACKUP_DIR}/" "${ANOTHER_SERVER_USERNAME}@${ANOTHER_SERVER_IP}:${ANOTHER_SERVER_ANOTHER_BACKUP_DIR}/" | tee -a "${BACKUP_LOG_FILE}"
    log "Push ${BACKUP_DIR} to ${ANOTHER_SERVER_IP}:${ANOTHER_SERVER_ANOTHER_BACKUP_DIR} finish"
}

# ------------------------------------------------------------
#  Security
# ------------------------------------------------------------
die_privileged() {
    die "Error: This script must not be run as root or with sudo (mass file/dir removal)."
}

# ------------------------------------------------------------
#  Block sudo
# ------------------------------------------------------------
sudo() {
    die_privileged
}

# ------------------------------------------------------------
#  Block doas
# ------------------------------------------------------------
doas() {
    die_privileged
}

# ------------------------------------------------------------
#  Block privileged execution
# ------------------------------------------------------------
block_root() {
    if [ "$(id -u)" -eq 0 ]
    then
        die_privileged
    fi
}

# ------------------------------------------------------------
#  Lint against popular Shell/command-line interpreters, special case of `sh` included
# ------------------------------------------------------------
lint_shell_script() {
    local SHELLS_TO_CHECK_AGAINST="bash sh"
    for shell in ${SHELLS_TO_CHECK_AGAINST}
    do
        printf "Testing %s\n" "${shell}"
        "${shell}" -n "$@"
    done
}
