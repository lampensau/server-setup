#!/bin/bash

# System configuration functions for the Unified Server Setup Framework

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Configure timezone and locale
configure_timezone_and_locale() {
    info "Configuring timezone and locale settings..."
    
    # Set timezone to UTC (or from environment variable)
    local target_timezone="${TIMEZONE:-$DEFAULT_TIMEZONE}"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        timedatectl set-timezone "$target_timezone"
        
        # Configure locale for UTF-8
        localectl set-locale LANG=en_US.UTF-8
        
        # Generate required locales if locale-gen is available
        if command -v locale-gen >/dev/null; then
            locale-gen en_US.UTF-8
        fi
        
        success "Timezone set to $target_timezone, locale configured for UTF-8"
    else
        info "[DRY RUN] Would set timezone to $target_timezone and configure UTF-8 locale"
    fi
}

# Setup NTP synchronization
setup_ntp_synchronization() {
    info "Setting up NTP synchronization with systemd-timesyncd..."
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Install timesyncd configuration from config structure
        atomic_install "$CONFIG_DIR/system/systemd/timesyncd.conf" "/etc/systemd/timesyncd.conf" "644" "root:root"
        
        # Enable NTP synchronization
        timedatectl set-ntp true
        
        # Restart timesyncd service
        systemctl restart systemd-timesyncd
        systemctl enable systemd-timesyncd
        
        success "NTP synchronization configured"
    else
        info "[DRY RUN] Would configure NTP synchronization"
    fi
}

# Configure persistent logging
configure_persistent_logging() {
    info "Setting up persistent journald logging..."
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Install journald configuration from config structure
        atomic_install "$CONFIG_DIR/system/systemd/journald.conf" "/etc/systemd/journald.conf" "644" "root:root"
        
        # Create persistent journal directory
        mkdir -p /var/log/journal
        systemd-tmpfiles --create --prefix /var/log/journal
        
        # Restart journald to apply new configuration
        systemctl restart systemd-journald
        
        # Install rsyslog configuration for log separation if available
        if [[ -f "$CONFIG_DIR/applications/logging/rsyslog-separation.conf" ]] && systemctl is-active --quiet rsyslog 2>/dev/null; then
            atomic_install "$CONFIG_DIR/applications/logging/rsyslog-separation.conf" "/etc/rsyslog.d/10-separation.conf" "644" "root:root"
            systemctl restart rsyslog
        elif [[ -f "$CONFIG_DIR/applications/logging/rsyslog-separation.conf" ]]; then
            info "rsyslog not available - skipping log separation configuration"
        fi
        
        success "Persistent logging configured"
    else
        info "[DRY RUN] Would configure persistent logging"
    fi
}

# Configure hostname and FQDN
configure_hostname() {
    local new_hostname="${HOSTNAME:-}"
    local domain="${DOMAIN:-}"
    
    if [[ -n "$new_hostname" ]]; then
        info "Configuring hostname to: $new_hostname"
        
        if [[ "$DRY_RUN" == "false" ]]; then
            # Update /etc/hosts if domain is provided
            if [[ -n "$domain" ]]; then
                local fqdn="$new_hostname.$domain"
                
                # Set hostname to FQDN for proper configuration
                hostnamectl set-hostname "$fqdn"
                
                # Use template if available, otherwise create basic entry
                if [[ -f "$CONFIG_DIR/system/network/hosts.template" ]]; then
                    export HOSTNAME="$new_hostname"
                    export DOMAIN="$domain"
                    export FQDN="$fqdn"
                    process_config_template "$CONFIG_DIR/system/network/hosts.template" "/etc/hosts" "HOSTNAME DOMAIN FQDN"
                else
                    # Basic hosts file update
                    sed -i '/^127\.0\.1\.1/d' /etc/hosts
                    echo "127.0.1.1 $fqdn $new_hostname" >> /etc/hosts
                fi
            else
                # Handle case where only hostname is set (no domain)
                hostnamectl set-hostname "$new_hostname"
                sed -i '/^127\.0\.1\.1/d' /etc/hosts
                echo "127.0.1.1 $new_hostname" >> /etc/hosts
            fi
            
            success "Hostname configured: $new_hostname"
        else
            info "[DRY RUN] Would configure hostname to: $new_hostname"
        fi
    else
        info "No hostname change requested"
    fi
}

# Configure kernel parameters
configure_kernel_parameters() {
    info "Configuring kernel parameters..."
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Install base sysctl configuration
        atomic_install "$CONFIG_DIR/system/sysctl/10-base.conf" "/etc/sysctl.d/10-base.conf" "644" "root:root"
        
        # Install virtualization-specific parameters if needed
        local virt_type="$(systemd-detect-virt 2>/dev/null || echo 'none')"
        case "$virt_type" in
            "none")
                # Bare metal configuration
                if [[ -f "$CONFIG_DIR/system/sysctl/71-baremetal.conf" ]]; then
                    atomic_install "$CONFIG_DIR/system/sysctl/71-baremetal.conf" "/etc/sysctl.d/71-baremetal.conf" "644" "root:root"
                fi
                ;;
            *)
                # Virtual machine configuration
                if [[ -f "$CONFIG_DIR/system/sysctl/70-vm.conf" ]]; then
                    atomic_install "$CONFIG_DIR/system/sysctl/70-vm.conf" "/etc/sysctl.d/70-vm.conf" "644" "root:root"
                fi
                ;;
        esac
        
        # Disable IPv6 if requested
        if [[ "${DISABLE_IPV6:-false}" == "true" ]]; then
            if [[ -f "$CONFIG_DIR/system/sysctl/80-ipv6-disable.conf" ]]; then
                atomic_install "$CONFIG_DIR/system/sysctl/80-ipv6-disable.conf" "/etc/sysctl.d/80-ipv6-disable.conf" "644" "root:root"
            fi
        fi
        
        success "Kernel parameters configured"
    else
        info "[DRY RUN] Would configure kernel parameters"
    fi
}

# Configure system limits
configure_system_limits() {
    info "Configuring system resource limits..."
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Install general system limits
        if [[ -f "$CONFIG_DIR/security/limits/limits-base.conf" ]]; then
            atomic_install "$CONFIG_DIR/security/limits/limits-base.conf" "/etc/security/limits.d/10-base.conf" "644" "root:root"
        fi
        
        success "System resource limits configured"
    else
        info "[DRY RUN] Would configure system resource limits"
    fi
}

# Configure log rotation
configure_log_rotation() {
    info "Configuring log rotation..."
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Install application log rotation configurations
        for logrotate_conf in "$CONFIG_DIR/applications/logging"/logrotate-*.conf; do
            if [[ -f "$logrotate_conf" ]]; then
                conf_name=$(basename "$logrotate_conf" | sed 's/logrotate-//')
                atomic_install "$logrotate_conf" "/etc/logrotate.d/$conf_name" "644" "root:root"
                info "Installed log rotation for: $conf_name"
            fi
        done
        
        # Test logrotate configuration
        if ! logrotate -d /etc/logrotate.conf >/dev/null 2>&1; then
            warn "Log rotation configuration may have issues"
        else
            success "Log rotation configured"
        fi
    else
        info "[DRY RUN] Would configure log rotation"
    fi
}

# Configure Message of the Day (MOTD)
configure_motd() {
    info "Configuring Message of the Day (MOTD)..."
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Disable default Ubuntu MOTD scripts if they exist
        if [[ -d /etc/update-motd.d ]]; then
            # Remove execute permissions from default scripts
            chmod -x /etc/update-motd.d/* 2>/dev/null || true
            
            # But keep the directory for our custom scripts
            info "Disabled default Ubuntu MOTD scripts"
        fi
        
        # Create MOTD directory if it doesn't exist
        mkdir -p /etc/update-motd.d
        
        # Install our custom MOTD scripts
        for motd_script in "$CONFIG_DIR/system/motd"/*; do
            if [[ -f "$motd_script" ]]; then
                script_name=$(basename "$motd_script")
                atomic_install "$motd_script" "/etc/update-motd.d/$script_name" "755" "root:root"
                info "Installed MOTD script: $script_name"
            fi
        done
        
        # Ensure motd-news is disabled (Ubuntu)
        if [[ -f /etc/default/motd-news ]]; then
            sed -i 's/ENABLED=1/ENABLED=0/' /etc/default/motd-news 2>/dev/null || true
        fi
        
        # Disable motd-news service if it exists
        if systemctl is-enabled --quiet motd-news.timer 2>/dev/null; then
            systemctl disable --now motd-news.timer 2>/dev/null || true
            systemctl disable --now motd-news.service 2>/dev/null || true
        fi
        
        # Create /etc/motd file (static part, can be empty)
        echo "" > /etc/motd
        
        success "MOTD configured with system information display"
    else
        info "[DRY RUN] Would configure MOTD with system information display"
    fi
}

# Configure APT for production use
configure_apt_production() {
    info "Configuring APT for production environment..."
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Install production APT configuration
        atomic_install "$CONFIG_DIR/applications/apt/apt-production.conf" "/etc/apt/apt.conf.d/99-production" "644" "root:root"
        
        # unattended-upgrades package should already be installed by centralized package manager
        
        # Install unattended upgrades configuration
        atomic_install "$CONFIG_DIR/applications/apt/unattended-upgrades.conf" "/etc/apt/apt.conf.d/50-unattended-upgrades" "644" "root:root"
        
        # Enable unattended upgrades
        systemctl enable --now unattended-upgrades
        
        success "APT configured for production use"
    else
        info "[DRY RUN] Would configure APT for production"
    fi
}

# Remove unnecessary packages
remove_unnecessary_packages() {
    info "Removing unnecessary packages..."
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Remove development packages (if SECURITY_PROFILE is hardened)
        if [[ "$SECURITY_PROFILE" == "hardened" ]]; then
            local packages_to_remove=($DEVEL_PACKAGES)
            
            # Add packages from custom removal list if it exists
            if [[ -f "$SCRIPT_DIR/packages-remove.conf" ]]; then
                while IFS= read -r package; do
                    # Skip comments and empty lines
                    [[ "$package" =~ ^[[:space:]]*# ]] && continue
                    [[ -z "$package" ]] && continue
                    packages_to_remove+=("$package")
                done < "$SCRIPT_DIR/packages-remove.conf"
            fi
            
            # Remove packages that are actually installed
            local installed_packages=()
            for package in "${packages_to_remove[@]}"; do
                if dpkg -l | grep -q "^ii.*$package"; then
                    installed_packages+=("$package")
                fi
            done
            
            if [[ ${#installed_packages[@]} -gt 0 ]]; then
                apt-get remove -y "${installed_packages[@]}" || true
                apt-get autoremove -y
                info "Removed development packages: ${installed_packages[*]}"
            fi
        fi
        
        # Clean package cache
        apt-get autoclean
        
        success "Package cleanup complete"
    else
        info "[DRY RUN] Would remove unnecessary packages"
    fi
}

# Apply all system configurations
apply_system_configuration() {
    info "Applying comprehensive system configuration..."
    
    # Core system setup
    configure_timezone_and_locale
    setup_ntp_synchronization
    configure_persistent_logging
    configure_hostname
    
    # System optimization
    configure_kernel_parameters
    configure_system_limits
    configure_log_rotation
    configure_motd
    
    # Package management
    configure_apt_production
    remove_unnecessary_packages
    
    success "System configuration complete"
}

# Test system configurations
test_system_configs() {
    info "Testing system configurations..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY RUN] Would test system configurations after applying changes"
        success "[DRY RUN] System configuration testing skipped"
        return 0
    fi
    
    # Test sysctl parameters
    for sysctl_file in /etc/sysctl.d/1*-*.conf; do
        if [[ -f "$sysctl_file" ]]; then
            local temp_test="/tmp/sysctl-test-$$"
            if ! sysctl -p "$sysctl_file" > "$temp_test" 2>&1; then
                error "Sysctl test failed for $sysctl_file:"
                cat "$temp_test"
                rm -f "$temp_test"
                return 1
            fi
            rm -f "$temp_test"
        fi
    done
    
    # Test logrotate configuration
    if ! logrotate -d /etc/logrotate.conf >/dev/null 2>&1; then
        error "Log rotation configuration test failed"
        return 1
    fi
    
    # Test systemd configurations
    if ! systemctl daemon-reload; then
        error "Systemd configuration reload failed"
        return 1
    fi
    
    success "System configuration tests passed"
}

# Display system status
show_system_status() {
    info "=== System Configuration Status ==="
    
    # Timezone and time sync
    echo "Timezone: $(timedatectl show --property=Timezone --value)"
    echo "NTP Sync: $(timedatectl show --property=NTPSynchronized --value)"
    echo ""
    
    # Hostname
    echo "Hostname: $(hostnamectl --static)"
    echo "FQDN: $(hostname -f 2>/dev/null || echo 'Not configured')"
    echo ""
    
    # System load
    echo "System Load: $(uptime | awk -F'load average:' '{print $2}')"
    echo "Memory Usage: $(free -h | grep '^Mem:' | awk '{print $3"/"$2}')"
    echo ""
    
    # Disk usage
    echo "Disk Usage:"
    df -h / | tail -1
    echo ""
    
    # Service status
    echo "Key Service Status:"
    for service in systemd-timesyncd systemd-journald systemd-resolved; do
        if systemctl is-active --quiet "$service"; then
            echo "$service: Active"
        else
            echo "$service: Inactive"
        fi
    done
}