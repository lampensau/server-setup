#!/bin/bash

# Common utility functions for the Unified Server Configuration Framework
# Combines SSH and System setup functionality

# Color codes for output
if [ -z "${RED-}" ]; then readonly RED='\033[0;31m'; fi
if [ -z "${GREEN-}" ]; then readonly GREEN='\033[0;32m'; fi
if [ -z "${YELLOW-}" ]; then readonly YELLOW='\033[1;33m'; fi
if [ -z "${BLUE-}" ]; then readonly BLUE='\033[0;34m'; fi
if [ -z "${NC-}" ]; then readonly NC='\033[0m'; fi # No Color

# System configuration constants
if [ -z "${DEFAULT_TIMEZONE-}" ]; then readonly DEFAULT_TIMEZONE="UTC"; fi
if [ -z "${BACKUP_DIR-}" ]; then readonly BACKUP_DIR="/root/server-backup-$(date +%Y%m%d-%H%M%S)"; fi

# Modern SSH Security Constants
if [ -z "${MODERN_KEXALGORITHMS-}" ]; then readonly MODERN_KEXALGORITHMS="sntrup761x25519-sha512@openssh.com,curve25519-sha256"; fi
if [ -z "${MODERN_CIPHERS-}" ]; then readonly MODERN_CIPHERS="chacha20-poly1305@openssh.com,aes256-gcm@openssh.com"; fi
if [ -z "${MODERN_MACS-}" ]; then readonly MODERN_MACS="hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com"; fi
if [ -z "${MODERN_HOSTKEY_ALGORITHMS-}" ]; then readonly MODERN_HOSTKEY_ALGORITHMS="ssh-ed25519"; fi
if [ -z "${MODERN_PUBKEY_ALGORITHMS-}" ]; then readonly MODERN_PUBKEY_ALGORITHMS="ssh-ed25519"; fi

# Export SSH algorithm variables for envsubst
export MODERN_KEXALGORITHMS MODERN_CIPHERS MODERN_MACS MODERN_HOSTKEY_ALGORITHMS MODERN_PUBKEY_ALGORITHMS

# SSH Configuration options with defaults (can be overridden by local.conf)
if [ -z "${ALLOW_AGENT_FORWARDING-}" ]; then ALLOW_AGENT_FORWARDING="yes"; fi
if [ -z "${ALLOW_TCP_FORWARDING-}" ]; then ALLOW_TCP_FORWARDING="yes"; fi

# Export SSH configuration variables for envsubst
export ALLOW_AGENT_FORWARDING ALLOW_TCP_FORWARDING
if [ -z "${ENABLE_USER_GROUPS-}" ]; then ENABLE_USER_GROUPS="false"; fi

# Package lists for removal (can be overridden by local config)
if [ -z "${DEVEL_PACKAGES-}" ]; then 
    readonly DEVEL_PACKAGES="build-essential gcc g++ make cmake autotools-dev libtool pkg-config python3-dev python3-pip python-dev-is-python3"
fi
if [ -z "${GUI_PACKAGES-}" ]; then 
    readonly GUI_PACKAGES="ubuntu-desktop gnome-desktop3-data xorg xserver-xorg-* x11-*"
fi
if [ -z "${CLOUD_PACKAGES-}" ]; then 
    readonly CLOUD_PACKAGES="amazon-ssm-agent google-cloud-sdk azure-cli"
fi

# Trusted checksums for downloaded binaries
declare -A TRUSTED_CHECKSUMS

# Unified logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_output="${timestamp} [${level}] ${message}"
    
    # Display to stdout
    echo -e "$log_output"
    
    # Try to log to file if we have permissions, otherwise skip silently
    if [[ -w "$(dirname "${LOG_FILE:-/var/log/server-setup.log}")" ]] 2>/dev/null; then
        echo -e "$log_output" >> "${LOG_FILE:-/var/log/server-setup.log}"
    elif [[ $EUID -eq 0 ]]; then
        # Only show permission error if running as root but still can't write
        echo "Warning: Cannot write to log file ${LOG_FILE:-/var/log/server-setup.log}" >&2
    fi
}

info() { log "INFO" "$*"; }
warn() { log "WARN" "${YELLOW}$*${NC}"; }
error() { log "ERROR" "${RED}$*${NC}"; }
success() { log "SUCCESS" "${GREEN}$*${NC}"; }

# Unified input validation function
validate_inputs() {
    info "Validating input parameters..."
    
    # Validate SSH_PORT if SSH mode is enabled
    if [[ "${SETUP_MODE:-both}" == "ssh" || "${SETUP_MODE:-both}" == "both" ]]; then
        if [[ ! "${SSH_PORT:-22}" =~ ^[0-9]+$ ]] || [[ "${SSH_PORT:-22}" -lt 1 ]] || [[ "${SSH_PORT:-22}" -gt 65535 ]]; then
            error "Invalid SSH port: ${SSH_PORT:-22}. Must be between 1-65535"
            exit 1
        fi
        
        # Validate SSH_MODE
        if [[ "${SSH_MODE:-both}" != "server" && "${SSH_MODE:-both}" != "client" && "${SSH_MODE:-both}" != "both" ]]; then
            error "Invalid SSH mode: ${SSH_MODE:-both}. Must be 'server', 'client', or 'both'"
            exit 1
        fi
    fi
    
    # Validate SETUP_MODE
    if [[ "${SETUP_MODE:-both}" != "system" && "${SETUP_MODE:-both}" != "ssh" && "${SETUP_MODE:-both}" != "both" ]]; then
        error "Invalid setup mode: ${SETUP_MODE:-both}. Must be 'system', 'ssh', or 'both'"
        exit 1
    fi
    
    # Validate SERVER_TYPE
    if [[ "${SERVER_TYPE:-bare}" != "bare" && "${SERVER_TYPE:-bare}" != "docker" && "${SERVER_TYPE:-bare}" != "web" ]]; then
        error "Invalid server type: ${SERVER_TYPE:-bare}. Must be 'bare', 'docker', or 'web'"
        exit 1
    fi
    
    # Validate SECURITY_PROFILE
    case "${SECURITY_PROFILE:-standard}" in
        "minimal"|"standard"|"hardened")
            ;;
        *)
            error "Invalid security profile: ${SECURITY_PROFILE:-standard}. Must be 'minimal', 'standard', or 'hardened'"
            exit 1
            ;;
    esac
    
    # Validate DRY_RUN
    if [[ "${DRY_RUN:-false}" != "true" && "${DRY_RUN:-false}" != "false" ]]; then
        error "Invalid dry run value: ${DRY_RUN:-false}. Must be 'true' or 'false'"
        exit 1
    fi
    
    success "Input validation passed"
}

# Unified backup creation
create_backup() {
    info "Creating comprehensive system backup..."
    
    if [[ "$DRY_RUN" == "false" ]]; then
        mkdir -p "$BACKUP_DIR"
        
        # Backup critical configuration files
        local backup_files=(
            "/etc/ssh/sshd_config"
            "/etc/ssh/ssh_config"
            "/etc/systemd/timesyncd.conf"
            "/etc/systemd/journald.conf"
            "/etc/systemd/resolved.conf"
            "/etc/hosts"
            "/etc/hostname"
            "/etc/fstab"
            "/etc/sysctl.conf"
            "/etc/security/limits.conf"
            "/etc/apt/apt.conf"
            "/etc/default/grub"
            "/etc/fail2ban/jail.local"
        )
        
        for file in "${backup_files[@]}"; do
            if [[ -f "$file" ]]; then
                cp "$file" "$BACKUP_DIR/$(basename "$file").backup" 2>/dev/null || true
            fi
        done
        
        # Backup directories
        cp -r /etc/ssh/sshd_config.d "$BACKUP_DIR/sshd_config.d.backup" 2>/dev/null || true
        cp -r /etc/sysctl.d "$BACKUP_DIR/sysctl.d.backup" 2>/dev/null || true
        cp -r /etc/systemd/system "$BACKUP_DIR/systemd-system.backup" 2>/dev/null || true
        cp -r /etc/security/limits.d "$BACKUP_DIR/limits.d.backup" 2>/dev/null || true
        cp -r /etc/fail2ban/jail.d "$BACKUP_DIR/fail2ban-jail.d.backup" 2>/dev/null || true
        
        # Create unified restoration script from template
        atomic_install "$SCRIPT_DIR/templates/system/restore.sh.template" "$BACKUP_DIR/restore.sh" "755" "root:root"
        
        success "Backup created in: $BACKUP_DIR"
    else
        info "[DRY RUN] Would create backup in: $BACKUP_DIR"
    fi
}

# Unified rollback function
rollback_config() {
    local backup_dir="$1"
    info "Rolling back server configuration..."
    
    if [[ -f "$backup_dir/restore.sh" ]]; then
        "$backup_dir/restore.sh"
    else
        error "Restore script not found in: $backup_dir"
        return 1
    fi
}

# Enhanced error handling with unified cleanup
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        error "Script failed with exit code $exit_code"
        error "Check log file: $LOG_FILE"
        
        if [[ -d "$BACKUP_DIR" ]]; then
            warn "Server backup available at: $BACKUP_DIR"
            warn "To restore: $BACKUP_DIR/restore.sh"
        fi
        
        # Offer specific rollback suggestions based on what was being configured
        if [[ -f "/etc/ssh/sshd_config.backup.$(date +%Y%m%d)" ]]; then
            warn "SSH configuration backup available. Consider testing SSH before disconnecting."
        fi
    fi
}

# Unified dependency checking
check_dependencies() {
    info "Checking for required dependencies..."
    local missing_cmds=()
    local base_commands=(
        "systemctl" "timedatectl" "localectl" "hostnamectl"
        "apt-get" "dpkg" "sysctl" "journalctl" "logrotate" "crontab"
    )
    local ssh_commands=(
        "ssh" "sshd" "ssh-keygen" "fail2ban-client"
    )
    local network_commands=(
        "ufw" "iptables" "iptables-restore" "nc"
    )
    local utility_commands=(
        "curl" "wget" "gpg" "git" "python3" "pip3" "jq" "envsubst"
    )
    
    local required_commands=("${base_commands[@]}")
    
    # Add SSH commands if SSH setup is enabled
    if [[ "${SETUP_MODE:-both}" == "ssh" || "${SETUP_MODE:-both}" == "both" ]]; then
        required_commands+=("${ssh_commands[@]}")
        required_commands+=("${network_commands[@]}")
    fi
    
    # Add utility commands for both modes
    required_commands+=("${utility_commands[@]}")
    
    # Add update-grub only for non-virtualized environments
    local virt_type="$(systemd-detect-virt 2>/dev/null || echo 'none')"
    if [[ "$virt_type" == "none" ]] && [[ "${SETUP_MODE:-both}" == "system" || "${SETUP_MODE:-both}" == "both" ]]; then
        required_commands+=("update-grub")
    else
        info "Detected virtualized environment ($virt_type) - skipping update-grub requirement"
    fi

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_cmds+=("$cmd")
        fi
    done

    if [[ ${#missing_cmds[@]} -gt 0 ]]; then
        error "Missing required commands: ${missing_cmds[*]}"

        declare -A cmd_to_pkg_map
        cmd_to_pkg_map=(
            [gpg]="gnupg2"
            [sshd]="openssh-server"
            [ssh]="openssh-client"
            [ssh-keygen]="openssh-client"
            [fail2ban-client]="fail2ban"
            [nc]="netcat-openbsd"
            [iptables-restore]="iptables"
            [pip3]="python3-pip"
            [envsubst]="gettext-base"
        )

        local packages_to_install=()
        for cmd in "${missing_cmds[@]}"; do
            if [[ -v "cmd_to_pkg_map[$cmd]" ]]; then
                packages_to_install+=("${cmd_to_pkg_map[$cmd]}")
            else
                packages_to_install+=("$cmd")
            fi
        done

        local unique_packages=($(printf "%s\n" "${packages_to_install[@]}" | sort -u))

        info "The following packages will be installed: ${unique_packages[*]}"
        read -p "Do you want to install them now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            info "Installing missing dependencies..."
            if ! apt-get update || ! apt-get install -y "${unique_packages[@]}"; then
                error "Failed to install dependencies. Please install them manually."
                exit 1
            fi
            success "Dependencies installed successfully."
        else
            error "Please install dependencies before running this script."
            exit 1
        fi
    fi
    success "All dependencies are available."
}

# Check OpenSSH version (for SSH mode)
check_openssh_version() {
    if [[ "${SETUP_MODE:-both}" == "ssh" || "${SETUP_MODE:-both}" == "both" ]]; then
        info "Checking OpenSSH version..."
        local ssh_version=$(ssh -V 2>&1 | sed 's/.*_//;s/ .*//')
        local required_version="7.9"

        if ! dpkg --compare-versions "$ssh_version" "ge" "$required_version"; then
            error "OpenSSH version $ssh_version is too old."
            error "Version $required_version or newer is required for modern security features."
            exit 1
        fi
        success "OpenSSH version $ssh_version is compatible."
    fi
}

# Atomic file installation
atomic_install() {
    local src="$1"
    local dest="$2"
    local permissions="${3:-}"
    local owner="${4:-}"

    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY RUN] Would install $src -> $dest"
        return
    fi

    if [[ ! -f "$src" ]]; then
        error "Source file not found: $src"
        return 1
    fi

    # Ensure destination directory exists
    local dest_dir
    dest_dir="$(dirname "$dest")"
    mkdir -p "$dest_dir"

    local tmp_dest
    tmp_dest="$(mktemp "${dest}.XXXXXX")"
    cp "$src" "$tmp_dest"
    
    if [[ -n "$permissions" ]]; then
        chmod "$permissions" "$tmp_dest"
    fi
    if [[ -n "$owner" ]]; then
        chown "$owner" "$tmp_dest"
    fi
    
    mv "$tmp_dest" "$dest"
}

# Template processing with variable substitution
process_config_template() {
    local template="$1"
    local output="$2"
    local required_vars="$3"

    # Validate required variables are set
    # Split the space-separated variable names and validate each
    local IFS=' '
    read -ra var_list <<< "$required_vars"
    for var in "${var_list[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            error "Required variable $var not set for template $template"
            return 1
        fi
    done

    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY RUN] Would process template $template -> $output"
        return
    fi

    # Use envsubst to process the template
    if ! envsubst < "$template" > "$output"; then
        error "Failed to process template $template"
        return 1
    fi

    return 0
}

# Verify file checksum
verify_checksum() {
    local file="$1"
    local expected_checksum="$2"
    local algorithm="${3:-sha256}"
    
    if [[ ! -f "$file" ]]; then
        error "File not found for checksum verification: $file"
        return 1
    fi
    
    local actual_checksum
    case "$algorithm" in
        "sha256")
            actual_checksum=$(sha256sum "$file" | cut -d' ' -f1)
            ;;
        "sha512")
            actual_checksum=$(sha512sum "$file" | cut -d' ' -f1)
            ;;
        *)
            error "Unsupported checksum algorithm: $algorithm"
            return 1
            ;;
    esac
    
    if [[ "$expected_checksum" != "$actual_checksum" ]]; then
        error "Checksum verification failed for $file"
        error "Expected: $expected_checksum"
        error "Actual: $actual_checksum"
        return 1
    fi
    
    success "Checksum verification passed for $file"
}

# Update system packages
update_system() {
    info "Updating system packages..."
    if [[ "$DRY_RUN" == "false" ]]; then
        apt-get update
        apt-get upgrade -y
        
        # Install essential logging system
        if ! systemctl is-active --quiet rsyslog 2>/dev/null; then
            info "Installing rsyslog for enhanced logging..."
            apt-get install -y rsyslog
            systemctl enable --now rsyslog
        fi
    else
        info "[DRY RUN] Would update system packages and install rsyslog"
    fi
    success "System packages updated"
}

# Display unified pre-execution configuration
display_configuration() {
    info "Current Configuration:"
    echo "- Setup Mode: $SETUP_MODE"
    echo "- Server Type: $SERVER_TYPE"
    if [[ "${SETUP_MODE:-both}" == "ssh" || "${SETUP_MODE:-both}" == "both" ]]; then
        echo "- SSH Port: $SSH_PORT"
        echo "- SSH Mode: $SSH_MODE"
    fi
    echo "- Security Profile: $SECURITY_PROFILE"
    echo "- Dry Run: $DRY_RUN"
    echo "- Config Dir: $CONFIG_DIR"
    echo "- Backup Dir: $BACKUP_DIR"
    echo "- Log File: $LOG_FILE"
    echo ""
    read -p "Continue with this configuration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Aborted by user"
        exit 0
    fi
}

# Unified safety checks
safety_check() {
    info "Performing safety checks..."
    
    # Check if we're connected via SSH (for SSH configurations)
    if [[ "${SETUP_MODE:-both}" == "ssh" || "${SETUP_MODE:-both}" == "both" ]]; then
        if [[ -n "${SSH_CLIENT:-}" || -n "${SSH_TTY:-}" ]]; then
            warn "You are connected via SSH. This script will create backup configs and test before applying changes."
            warn "Keep this terminal open and test in a NEW terminal session."
            echo ""
            read -p "Continue with safety measures enabled? (y/N): " confirm
            if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                info "Aborted for safety"
                exit 0
            fi
            export SSH_CONNECTION_ACTIVE=true
        else
            export SSH_CONNECTION_ACTIVE=false
        fi
    fi
    
    # Check if we're in a container (for system configurations)
    if [[ "${SETUP_MODE:-both}" == "system" || "${SETUP_MODE:-both}" == "both" ]]; then
        if [[ -f /.dockerenv ]] || grep -q 'container=docker\|container=lxc' /proc/1/environ 2>/dev/null; then
            warn "Running in a container environment - some configurations may not apply"
            read -p "Continue anyway? (y/N): " confirm
            if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                info "Aborted for safety"
                exit 0
            fi
        fi
    fi
    
    # Check available disk space
    local available_space=$(df /var --output=avail | tail -1)
    if [[ $available_space -lt 1000000 ]]; then  # Less than 1GB
        warn "Low disk space available. Some operations may fail."
        read -p "Continue? (y/N): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            info "Aborted due to disk space"
            exit 0
        fi
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            warn "Running in dry-run mode without root privileges - some checks may be limited"
        else
            echo "Error: This script must be run with root privileges. Try: sudo $0 $*" >&2
            exit 1
        fi
    fi
}

# Detect OS and version
detect_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS_ID="$ID"
        OS_VERSION="$VERSION_ID"
        OS_CODENAME="${VERSION_CODENAME:-}"
    else
        error "Cannot detect OS version"
        exit 1
    fi

    info "Detected OS: $OS_ID $OS_VERSION ($OS_CODENAME)"
    
    case "$OS_ID" in
        "ubuntu"|"debian")
            # Check if it's a cloud image
            if dpkg -l | grep -q cloud-init; then
                export IS_CLOUD_IMAGE=true
                info "Cloud image detected"
            else
                export IS_CLOUD_IMAGE=false
            fi
            ;;
        *)
            error "Unsupported OS: $OS_ID"
            exit 1
            ;;
    esac
    
    # Check for systemd
    if ! systemctl --version >/dev/null 2>&1; then
        error "This script requires systemd"
        exit 1
    fi
    
    # Detect if Ubuntu uses Netplan
    if [[ "$OS_ID" == "ubuntu" ]] && [[ -d "/etc/netplan" ]]; then
        export HAS_NETPLAN=true
        info "Netplan detected"
    else
        export HAS_NETPLAN=false
    fi
}

# Load local configuration overrides
load_local_config() {
    local local_config="$SCRIPT_DIR/local.conf"
    if [[ -f "$local_config" ]]; then
        info "Loading local configuration overrides..."
        source "$local_config"
        success "Local configuration loaded"
    fi
}

# Get the real user running the script, even with sudo
get_real_user() {
    if [[ -n "${SUDO_USER:-}" ]]; then
        echo "$SUDO_USER"
    else
        logname 2>/dev/null || whoami
    fi
}

# Helper function to check for active SSH connection
is_ssh_connection_active() {
    [[ -n "${SSH_CLIENT:-}" || -n "${SSH_TTY:-}" ]]
}

# Check if GRUB operations should be performed
should_update_grub() {
    local virt_type="$(systemd-detect-virt 2>/dev/null || echo 'none')"
    
    # Skip GRUB operations in virtualized environments that don't use GRUB
    case "$virt_type" in
        "wsl"|"container"|"docker"|"lxc"|"systemd-nspawn")
            return 1  # Don't update GRUB
            ;;
        "kvm"|"qemu"|"vmware"|"xen"|"microsoft"|"oracle"|"none")
            # Check if GRUB is actually installed
            if command -v update-grub &>/dev/null && [[ -d /boot/grub ]]; then
                return 0  # Update GRUB
            else
                return 1
            fi
            ;;
        *)
            # Unknown virtualization, be conservative
            if command -v update-grub &>/dev/null && [[ -d /boot/grub ]]; then
                return 0
            else
                return 1
            fi
            ;;
    esac
}

# Check if initramfs operations should be performed
should_update_initramfs() {
    local virt_type="$(systemd-detect-virt 2>/dev/null || echo 'none')"
    
    # Skip initramfs operations in environments that don't use it
    case "$virt_type" in
        "wsl"|"container"|"docker"|"lxc"|"systemd-nspawn")
            return 1
            ;;
        "kvm"|"qemu"|"vmware"|"xen"|"microsoft"|"oracle"|"none")
            # Check if initramfs tools are available
            if command -v update-initramfs &>/dev/null; then
                return 0
            else
                return 1
            fi
            ;;
        *)
            # Unknown virtualization, be conservative
            if command -v update-initramfs &>/dev/null; then
                return 0
            else
                return 1
            fi
            ;;
    esac
}

# Compare version strings (returns 0 if version1 >= version2)
version_greater_equal() {
    local version1="$1"
    local version2="$2"
    
    # Split versions into components and compare
    if [[ "$version1" == "$version2" ]]; then
        return 0
    fi
    
    # Use sort with version comparison
    local sorted_versions
    sorted_versions=$(printf '%s\n%s\n' "$version1" "$version2" | sort -V)
    local first_version
    first_version=$(echo "$sorted_versions" | head -n1)
    
    # If version2 is first in sorted order, then version1 >= version2
    if [[ "$first_version" == "$version2" ]]; then
        return 0
    else
        return 1
    fi
}

# Execute a function with a rollback mechanism
execute_with_rollback() {
    local func_name="$1"
    local rollback_func="$2"

    if ! "$func_name"; then
        error "Function $func_name failed"
        if [[ -n "$rollback_func" ]]; then
            warn "Attempting rollback with $rollback_func"
            "$rollback_func" || error "Rollback also failed!"
        fi
        return 1
    fi
    return 0
}

# Display final summary
display_summary() {
    info "=== Server Configuration Summary ==="
    echo "Setup Mode: $SETUP_MODE"
    echo "Server Type: $SERVER_TYPE"
    if [[ "${SETUP_MODE:-both}" == "ssh" || "${SETUP_MODE:-both}" == "both" ]]; then
        echo "SSH Port: $SSH_PORT"
        echo "SSH Mode: $SSH_MODE"
    fi
    echo "Security Profile: $SECURITY_PROFILE"
    echo "OS: $OS_ID $OS_VERSION"
    echo "Backup Location: $BACKUP_DIR"
    echo "Log File: $LOG_FILE"
    echo ""
    info "Server configuration complete!"
    if [[ "$DRY_RUN" == "false" ]]; then
        warn "Reboot recommended to ensure all changes take effect"
        if [[ "${SETUP_MODE:-both}" == "ssh" || "${SETUP_MODE:-both}" == "both" ]]; then
            warn "Test SSH access before disconnecting current session"
        fi
        read -p "Reboot now? (y/N): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            info "Rebooting system..."
            reboot
        fi
    fi
}