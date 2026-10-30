#!/bin/sh

# Detect CPU vendor and update specific variables (POSIX safe alternative to namerefs)
detect_cpu_architecture() {
    printf '\nDetecting CPU architecture...\n'

    if lsmod | grep -q "kvm_intel"
    then
        cpu_type="intel"
        module_name="kvm_intel"
        sys_file="/sys/module/kvm_intel/parameters/nested"
        conf_line="options kvm_intel nested=1"
    elif lsmod | grep -q "kvm_amd"
    then
        cpu_type="amd"
        module_name="kvm_amd"
        sys_file="/sys/module/kvm_amd/parameters/nested"
        conf_line="options kvm_amd nested=1"
    else
        printf 'Error: Neither kvm_intel nor kvm_amd module is currently loaded.\n'
        printf 'Please ensure hardware virtualization is enabled in your BIOS/UEFI settings.\n'
        exit 1
    fi

    printf 'Detected CPU Type:%s (%s)\n' "$cpu_type" "$module_name"
}

# Assess the current runtime state of the host
check_current_state() {
    _sys_file="${1}"
    _current_state=""

    if [ -e "${_sys_file}" ]
    then
        _current_state=$(cat "${_sys_file}")
        if [ "${_current_state}" = "Y" ] || [ "${_current_state}" = "1" ]
        then
            printf 'Nested virtualization is already active on this host (Runtime: %s).\n' "${_current_state}"
        else
            printf 'Nested virtualization is currently disabled (Runtime: %s).\n' "${_current_state}"
        fi
    else
        printf 'Error: Kernel parameter file not found at %s\n' "${_sys_file}"
        exit 1
    fi
}

# Handle permanent modprobe.d file creation
configure_persistence() {
    _conf_line="${1}"
    _conf_dir=$(dirname "${CONF_FILE}")

    printf '\n% Configuring persistent setting in %s...\n' "${CONF_FILE}"
    sudo mkdir -p "${_conf_dir}"

    # Using POSIX safe grep matching instead of bash specific flags
    if [ -e "$CONF_FILE" ] && grep -F "${_conf_line}" "${CONF_FILE}" >/dev/null 2>&1
    then
        printf 'Configuration line already present in %s.\n' "${CONF_FILE}"
    else
        printf '%s\n' "${_conf_line}" | sudo tee -a "${CONF_FILE}"
        printf 'Successfully appended configuration to %s.\n' "${CONF_FILE}"
    fi
}

# Handle user prompt and optional dynamic modprobe reload
apply_live_changes() {
    _module_name="${1}"
    _sys_file="${2}"
    _answer=""
    _new_state=""

    printf '\nAttempting live runtime activation...\n'
    printf 'Note: This requires stopping running virtual machines to reload kernel modules.\n'

    # Split prompt and read to maintain POSIX standard compliance (-p is not valid in standard sh)
    printf "Do you want to apply changes live right now? (y/N): "
    read -r _answer

    # POSIX case-insensitive match check replacing bash regex evaluations
    case "${_answer}" in
        [Yy]*)
            printf "Reloading ${_module_name} module..."

            if sudo modprobe -r "${_module_name}" >/dev/null 2>&1
            then
                sudo modprobe "${_module_name}" nested=1
                _new_state=$(cat "${_sys_file}")

                if [ "${_new_state}" = "Y" ] || [ "${_new_state}" = "1" ]
                then
                    printf 'Live update successful! Nested KVM is now active.\n'
                else
                    printf 'Failed to dynamically activate. A system reboot will be required.\n'
                fi
            else
                printf 'Warning: Could not unload module '%s' dynamically (resources or VMs are busy).\n' "${_module_name}"
                printf 'The changes will apply automatically upon your next system reboot.\n'
            fi
            ;;
        *)
            printf 'Skipped live update. Persistent settings are saved; please reboot manually.\n'
            ;;
    esac
}

# Output actionable post-execution instructions
print_next_steps() {
    printf '\nNext Steps & Guest Virtual Machine Configurations:\n'
    printf '1. Host Reboot: Turn off all virtual machines and execute: sudo reboot\n'
    printf '2. Guest VM Profile: Open Virtual Machine Manager (virt-manager) -> Guest VM -> CPUs -> check \"Copy host CPU configuration\".\n'
    printf '3. Guest Validation: Run sudo virt-host-validate inside your guest OS to confirm setup.\n'
}

# Main Orchestrator
main() {
    # Exit immediately if a command exits with a non-zero status
    set -e

    CONF_FILE="/etc/modprobe.d/kvm.conf"

    # Initialize scope variables explicitly to prevent global pollution
    cpu_type=""
    module_name=""
    sys_file=""
    conf_line=""

    detect_cpu_architecture
    check_current_state "${sys_file}"
    configure_persistence "${conf_line}"
    apply_live_changes "${module_name}" "${sys_file}"
    print_next_steps
}

# Execute main process
main
