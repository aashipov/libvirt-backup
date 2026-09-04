#!/bin/sh

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
#  Block elevated privilege execution
# ------------------------------------------------------------
block_root() {
    if [ "$(id -u)" -eq 0 ]
    then
        die_privileged
    fi
}
block_root

# ------------------------------------------------------------
#  lib.sh – Global variables
# ------------------------------------------------------------
CURRENT_BACKUP_DIR="/tmp"

# ------------------------------------------------------------
#  Utility helpers
# ------------------------------------------------------------

_log() {
    if [ -n "${BACKUP_LOG_FILE:-}" ] && [ -f "${BACKUP_LOG_FILE}" ]
    then
        printf '%s - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${1}" | tee -a "${BACKUP_LOG_FILE}"
    else
        # BACKUP_LOG_FILE not set yet (e.g. missing .env) — stdout only
        printf '%s - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${1}"
    fi
}

log() {
    _log "${1}"
}

die() {
    _log "${1}"
    exit 1
}

_fail() {
    printf '%s\n' "${@}"
    exit 1
}

# ------------------------------------------------------------
#  Fail if a variable value is blank or unsafe
#  Rejects:
#   - blank/unset values
#   - values made only of '/' characters ('/', '////')
#   - relative paths ('backup', 'foo/bar')
#   - unexpanded variable expansions ('$HOME', '${VAR}')
#   - tilde home shorthands ('~/backup')
#   - '..' path traversal ('../x', '/a/../b')
#   - multiple slashes in a row ('//', '/a//b')
#   - shell metacharacters: backticks, parentheses, curly braces, square brackets
# ------------------------------------------------------------
_check_path() {
    local VAR_NAME="${1}"
    local VAR_VALUE="${2}"
    local USERS_HOME="${HOME}"

    case "${VAR_VALUE}" in
        '')           die "${VAR_NAME} is blank" ;;
        "${USERS_HOME}"|"${USERS_HOME}/") die "${VAR_NAME} refers user's home directory" ;;
        *'$'*)        die "${VAR_NAME} contains an unexpanded variable expansion (${VAR_VALUE})" ;;
        *'~'*)        die "${VAR_NAME} contains a tilde '~' — use an absolute path (${VAR_VALUE})" ;;
        *'..'*)       die "${VAR_NAME} contains '..' — path traversal is not allowed (${VAR_VALUE})" ;;
        *'//'*)       die "${VAR_NAME} contains multiple slashes in a row (${VAR_VALUE})" ;;
        /*)           : ;;
        *)            die "${VAR_NAME} is not an absolute path (${VAR_VALUE})" ;;
    esac

    case "${VAR_VALUE}" in
        *[!a-zA-Z0-9/_.-]*)  die "${VAR_NAME} contains unsafe characters (${VAR_VALUE}) — only alphanumeric, '/', '_', '.', and '-' are allowed" ;;
    esac

    case "${VAR_VALUE}" in
        *[!/]*)       : ;;
        *)            die "${VAR_NAME} contains only slashes (${VAR_VALUE})" ;;
    esac
}

# ------------------------------------------------------------
#  Configure user's uri_default for qemu:///system
# ------------------------------------------------------------
check_libvirt() {
    virsh version >/dev/null 2>&1 || die "Cannot reach libvirt (is libvirtd running?)"
    if [ ! -f "$HOME/.config/libvirt/libvirt.conf" ] || ! grep -q '^uri_default *= *"qemu:///system"' "$HOME/.config/libvirt/libvirt.conf"
    then
        export LIBVIRT_DEFAULT_URI="qemu:///system"
    fi
}

# ------------------------------------------------------------
#  Check if qemu-img is installed
# ------------------------------------------------------------
check_qemu_img() {
    qemu-img --version >/dev/null 2>&1 || die "Cannot reach qemu-img (is qemu-img installed?)"
}

# ------------------------------------------------------------
#  Check if all of the mandatory variables are set in the environment
# ------------------------------------------------------------
check_mandatory_variables_set() {
    # .env.template is a single source of truth for mandatory variables
    local MANDATORY_VARIABLES_NAMES="$(awk -F= '!/^#/ && !/^$/ {print $1}' "$(dirname "$(readlink -f "${0}")")"/.env.template)"
    # set -f prevents pathname expansion of names read from .env.template
    set -f
    for VAR_PTR in ${MANDATORY_VARIABLES_NAMES}
    do
        # Names from .env.template are interpolated via eval below, so they
        # must be valid shell identifiers before being used
        case "${VAR_PTR}" in
            ''|[!A-Za-z_]*|*[!A-Za-z0-9_]*) die "Invalid variable name in .env.template: ${VAR_PTR}" ;;
        esac
        eval "VAR_VALUE=\"\${${VAR_PTR}:-}\""
        if [ -z "${VAR_VALUE}" ]
        then
            die "Mandatory variable ${VAR_PTR} is not defined or blank"
        else
            eval "readonly ${VAR_PTR}"
        fi
    done
    set +f
    _check_path "BACKUP_DIR" "${BACKUP_DIR}"
    _check_path "ANOTHER_SERVER_ANOTHER_BACKUP_DIR" "${ANOTHER_SERVER_ANOTHER_BACKUP_DIR}"
    # DAYS_TO_KEEP_BACKUPS feeds `find -mtime`: a leading '+' is mandatory for
    # the 'older than N days' semantic (a bare number would match a 24h window,
    # e.g. 0 would delete everything modified in the last day)
    case "${DAYS_TO_KEEP_BACKUPS}" in
        '+'[0-9]*) : ;;
        *) die "DAYS_TO_KEEP_BACKUPS must be of the form '+N' (older than N days), got '${DAYS_TO_KEEP_BACKUPS}'" ;;
    esac
}

# ------------------------------------------------------------
#  Environment loading
# ------------------------------------------------------------
environment() {
    # Loads environment variables from .env
    local ENV_FILE="$(dirname -- "$(readlink -f -- "$0")")/.env"
    if [ ! -f "${ENV_FILE}" ]
    then
        die "No ${ENV_FILE} file found, craft one from ${ENV_FILE}.template"
    fi
    # . for bash, zsh, ksh, (d)ash. source for (t)csh
    . "${ENV_FILE}"
    check_mandatory_variables_set
    check_libvirt
    check_qemu_img
    export LC_ALL=C
    CURRENT_BACKUP_DIR="${BACKUP_DIR}/$(date +%Y-%m-%d)"
    # Uncomment following line to observe locale issues
    #export LANGUAGE=ru_RU:ru LANG=ru_RU.UTF-8 LC_ALL=ru_RU.UTF-8
}

create_backup_dir() {
    # Creates a local backup dir if missing
    mkdir -p "${BACKUP_DIR}" || die "Can not create ${BACKUP_DIR}"
    local ACTUAL_DISK_FREE_SPACE
    ACTUAL_DISK_FREE_SPACE=$(df -Pk "${BACKUP_DIR}" | awk -v target="Available" 'NR==1 { for(i=1;i<=NF;i++) if($i==target) col=i } NR==2 { print $col }') || die "Failed to calculate free disk space in ${BACKUP_DIR}"
    if [ "${ACTUAL_DISK_FREE_SPACE}" -lt "${MINIMUM_FREE_DISK_SPACE_REQUIRED}" ]
    then
        die "Insufficient disk space in ${BACKUP_DIR}"
    fi
    mkdir -p "${ANOTHER_SERVER_ANOTHER_BACKUP_DIR}" || die "Can not create ${ANOTHER_SERVER_ANOTHER_BACKUP_DIR}"
    touch "${BACKUP_LOG_FILE}"
}

create_current_backup_dir() {
    # Creates a ${BACKUP_DIR}/YYYY-mm-dd for the current run of the script
    _check_path "CURRENT_BACKUP_DIR" "${CURRENT_BACKUP_DIR}"
    mkdir -p "${CURRENT_BACKUP_DIR}" || die "Can not create CURRENT_BACKUP_DIR dir ${CURRENT_BACKUP_DIR}"
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
    # Filter on the Device column ('disk') to skip cdrom and avoid false
    # positives from source paths containing the word 'disk'
    local _VM_NAME="${1}"
    local DISK_FILES="$(virsh domblklist --details "${_VM_NAME}" | awk '$2 == "disk" && $4 != "-" {print $3 "|" $4}')"
    if [ -z "${DISK_FILES}" ]
    then
        die "Could not parse disk list for ${_VM_NAME}"
    fi
    printf "%s\n" "${DISK_FILES}"
}

# ------------------------------------------------------------
#  Build qemu-img convert w (w/o) compression command
# ------------------------------------------------------------
build_qemu_img_convert_cmd() {
    if [ "${QEMU_IMG_CONVERT_WITH_COMPRESSION}" = "1" ]
    then
        printf "%s\n" "qemu-img convert -O qcow2 -o compression_type=zstd -c"
    else
        printf "%s\n" "qemu-img convert -O qcow2 -o compression_type=zstd"
    fi
}

# ------------------------------------------------------------
#  Online (live, running VM) backup
# ------------------------------------------------------------
online_backup() {
    # VM_BACKUP_DIR is set up the call stack
    # Collect VM disk file paths to PSV file
    local VM_DISKS_FILE="${VM_BACKUP_DIR}/disks.psv"
    get_vm_disk_names_and_absolute_paths "${VM_NAME}" > "${VM_DISKS_FILE}"

    # Backup job descriptor content
    local BACKUP_JOB_DESCRIPTOR_CONTENT="<domainbackup>\n    <disks>"
    local DISK_NAME
    local DISK_FILE_ABSOLUTE_PATH
    while IFS='|' read -r DISK_NAME DISK_FILE_ABSOLUTE_PATH
    do
        local DISK_FILE_NAME
        DISK_FILE_NAME="$(basename "${DISK_FILE_ABSOLUTE_PATH}")"
        local TARGET_DISK_FILE_ABSOLUTE_PATH="${VM_BACKUP_DIR}/${DISK_FILE_NAME}"

        # Workaround target file permissions
        local TARGET_DISK_CAPACITY
        TARGET_DISK_CAPACITY="$(virsh domblkinfo "${VM_NAME}" "${DISK_NAME}" | awk '$1 == "Capacity:" {print $2}')"
        if [ -z "${TARGET_DISK_CAPACITY}" ]
        then
            die "Failed to get capacity for ${VM_NAME} ${DISK_NAME}"
        fi
        qemu-img create -f qcow2 -o compression_type=zstd "${TARGET_DISK_FILE_ABSOLUTE_PATH}" "${TARGET_DISK_CAPACITY}" || die "Failed to create a target file for ${TARGET_DISK_FILE_ABSOLUTE_PATH}"

        BACKUP_JOB_DESCRIPTOR_CONTENT="${BACKUP_JOB_DESCRIPTOR_CONTENT}\n        <disk name='${DISK_NAME}' type='file'>\n            <target file='${TARGET_DISK_FILE_ABSOLUTE_PATH}'/>\n                <driver type='qcow2'/>\n        </disk>\n"
    done < "${VM_DISKS_FILE}"
    BACKUP_JOB_DESCRIPTOR_CONTENT="${BACKUP_JOB_DESCRIPTOR_CONTENT}    </disks>\n</domainbackup>"

    local BACKUP_TASK_FILE="${VM_BACKUP_DIR}/${VM_NAME}-backup-job-descriptor.xml"
    # printf "%s\n" "${BACKUP_JOB_DESCRIPTOR_CONTENT}" would produce an unparseable XML
    printf '%b\n' "${BACKUP_JOB_DESCRIPTOR_CONTENT}" > "${BACKUP_TASK_FILE}"

    # launch backup
    virsh backup-begin "${VM_NAME}" --reuse-external --backupxml "${BACKUP_TASK_FILE}" || die "Failed to start backup for ${VM_NAME}"

    # wait completion (bounded by BACKUP_TIMEOUT_SECONDS)
    local BACKUP_DEADLINE=$(( $(date +%s) + BACKUP_TIMEOUT_SECONDS ))
    while :; do
        # timeout?
        if [ "$(date +%s)" -ge "${BACKUP_DEADLINE}" ]
        then
            log "Backup job for ${VM_NAME} did not finish within ${BACKUP_TIMEOUT_SECONDS}s"
            cleanup_on_exit
        fi
        # job complete?
        if virsh domjobinfo "${VM_NAME}" | grep -q "None"
        then
            break
        fi
        # wait
        sleep 10
    done

    if [ "${QEMU_IMG_CONVERT_WITH_COMPRESSION}" = "1" ]
    then
        local QEMU_IMG_CONVERT_CMD="$(build_qemu_img_convert_cmd)"
        for backup_to_shrink in "${VM_BACKUP_DIR}"/*.qcow2
        do
            [ -f "${backup_to_shrink}" ] || continue
            local SHRUNK_BACKUP="${backup_to_shrink}-shrunk"
            log "Converting ${backup_to_shrink} to ${SHRUNK_BACKUP}"
            eval "${QEMU_IMG_CONVERT_CMD} ${backup_to_shrink} ${SHRUNK_BACKUP}" || die "Failed to convert ${backup_to_shrink} to ${SHRUNK_BACKUP}"
            rm "${backup_to_shrink}" || die "Failed to remove ${backup_to_shrink}"
        done
    fi
}

# ------------------------------------------------------------
#  Offline (shut down VM) backup
# ------------------------------------------------------------
offline_backup() {
    # VM_BACKUP_DIR is set up the call stack
    # Collect VM disk file paths to PSV file
    local VM_DISKS_FILE="${VM_BACKUP_DIR}/disks.psv"
    get_vm_disk_names_and_absolute_paths "${VM_NAME}" > "${VM_DISKS_FILE}"

    local QEMU_IMG_CONVERT_CMD="$(build_qemu_img_convert_cmd)"
    local DISK_NAME
    local DISK_FILE_ABSOLUTE_PATH
    while IFS='|' read -r DISK_NAME DISK_FILE_ABSOLUTE_PATH
    do
        local DISK_FILE_NAME
        DISK_FILE_NAME="$(basename "${DISK_FILE_ABSOLUTE_PATH}")"
        local TARGET_DISK_FILE_ABSOLUTE_PATH="${VM_BACKUP_DIR}/${DISK_FILE_NAME}"
        log "Converting ${DISK_FILE_ABSOLUTE_PATH} to ${TARGET_DISK_FILE_ABSOLUTE_PATH}"
        eval "${QEMU_IMG_CONVERT_CMD} ${DISK_FILE_ABSOLUTE_PATH} ${TARGET_DISK_FILE_ABSOLUTE_PATH}" || die "Failed to convert ${DISK_FILE_ABSOLUTE_PATH} to ${TARGET_DISK_FILE_ABSOLUTE_PATH}"
    done < "${VM_DISKS_FILE}"
}

# ------------------------------------------------------------
#  Back the VM up
# ------------------------------------------------------------
backup_vm() {
    # Exports VM configuration (XML) and copies disks
    local VM_NAME="${1}"
    log "${VM_NAME} backup start"

    # Per-VM dir in the ${CURRENT_BACKUP_DIR}
    local VM_BACKUP_DIR="${CURRENT_BACKUP_DIR}/${VM_NAME}"
    _check_path "VM_BACKUP_DIR" "${VM_BACKUP_DIR}"
    mkdir -p "${VM_BACKUP_DIR}" || die "Failed to create ${VM_BACKUP_DIR}"

    # Dump VM config
    virsh dumpxml --migratable "${VM_NAME}" > "${VM_BACKUP_DIR}/${VM_NAME}.xml" || die "Failed to dump an XML config for ${VM_NAME}"

    # Capture VM state once and reuse it below: polling `virsh domstate` per-disk
    # (and again after the loop) could see a state flip mid-run (VM started or
    # stopped), which would mix offline disk copies and live backup jobs for a
    # single VM
    local VM_STATE
    VM_STATE="$(virsh domstate "${VM_NAME}")" || die "Failed to get ${VM_NAME} state"
    local IS_VM_RUNNING=0
    if printf '%s\n' "${VM_STATE}" | grep -q "running"
    then
        IS_VM_RUNNING=1
        log "${VM_NAME} is running, will use a live backup job"
        online_backup
    elif printf '%s\n' "${VM_STATE}" | grep -q "paused"
    then
        log "${VM_NAME} is paused, skipping"
        return 0
    else
        log "${VM_NAME} is not running, will use an offline backup"
        offline_backup
    fi
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
#  Validate *.qcow2 files in "${CURRENT_BACKUP_DIR}"
# ------------------------------------------------------------
validate_backups() {
    local BACKUPS_TO_CHECK_FILE="${CURRENT_BACKUP_DIR}/.backups-to-check.txt"
    find "${CURRENT_BACKUP_DIR}" -type f \( -name '*.qcow2' -o -name '*.qcow2-shrunk' \) > "${BACKUPS_TO_CHECK_FILE}" || die "Failed to list backups in ${CURRENT_BACKUP_DIR}"
    while IFS= read -r line
    do
        log "=== Analyzing: ${line} ==="
        qemu-img info "${line}" || die "qemu-img info failed for ${line}"
        qemu-img check "${line}" || die "qemu-img check failed for ${line}"
    done < "${BACKUPS_TO_CHECK_FILE}"
    rm -f "${BACKUPS_TO_CHECK_FILE}"
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
    rsync --times --partial --recursive --delete --rsh="ssh -o BatchMode=yes" "${BACKUP_DIR}/" "${ANOTHER_SERVER_USERNAME}@${ANOTHER_SERVER_IP}:${ANOTHER_SERVER_ANOTHER_BACKUP_DIR}/" || die "Push failed"
    log "Push ${BACKUP_DIR} to ${ANOTHER_SERVER_IP}:${ANOTHER_SERVER_ANOTHER_BACKUP_DIR} finish"
}
