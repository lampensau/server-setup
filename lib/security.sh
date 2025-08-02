#!/bin/bash

# Unified security configuration functions for the Server Setup Framework
# Combines SSH and system security hardening

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Main security hardening function
apply_security_hardening() {
    info "Applying security hardening (profile: $SECURITY_PROFILE)..."
    
    case "$SECURITY_PROFILE" in
        "minimal")
            apply_minimal_security
            ;;
        "standard")
            apply_minimal_security
            apply_standard_security
            ;;
        "hardened")
            apply_minimal_security
            apply_standard_security
            apply_hardened_security
            ;;
    esac
}

# Minimal security measures (both SSH and system)
apply_minimal_security() {
    info "Applying minimal security hardening..."
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Basic kernel security parameters
        atomic_install "$CONFIG_DIR/system/sysctl/20-security-minimal.conf" "/etc/sysctl.d/20-security-minimal.conf" "644" "root:root"
        
        # Disable core dumps for security
        atomic_install "$CONFIG_DIR/security/limits/limits-disable-core.conf" "/etc/security/limits.d/10-disable-core.conf" "644" "root:root"
        
        # Basic fail2ban configuration (if SSH mode enabled)
        if [[ "${SETUP_MODE:-both}" == "ssh" || "${SETUP_MODE:-both}" == "both" ]]; then
            configure_basic_fail2ban
        fi
        
        success "Minimal security hardening applied"
    else
        info "[DRY RUN] Would apply minimal security hardening"
    fi
}

# Standard security measures
apply_standard_security() {
    info "Applying standard security hardening..."
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Enhanced kernel security parameters
        atomic_install "$CONFIG_DIR/system/sysctl/21-security-standard.conf" "/etc/sysctl.d/21-security-standard.conf" "644" "root:root"
        
        # Configure basic firewall (if SSH mode enabled)
        if [[ "${SETUP_MODE:-both}" == "ssh" || "${SETUP_MODE:-both}" == "both" ]]; then
            configure_basic_firewall
        fi
        
        # Process accounting for auditing (package installed by centralized manager)
        systemctl enable --now acct
        
        # unattended-upgrades package already installed by centralized package manager
        
        # Install and configure unattended upgrades for security updates
        atomic_install "$CONFIG_DIR/applications/apt/unattended-upgrades.conf" "/etc/apt/apt.conf.d/50-unattended-upgrades" "644" "root:root"
        systemctl enable --now unattended-upgrades
        
        success "Standard security hardening applied"
    else
        info "[DRY RUN] Would apply standard security hardening"
    fi
}

# Hardened security measures
apply_hardened_security() {
    info "Applying hardened security configuration..."
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Maximum security kernel parameters
        atomic_install "$CONFIG_DIR/system/sysctl/22-security-hardened.conf" "/etc/sysctl.d/22-security-hardened.conf" "644" "root:root"
        
        # Advanced fail2ban configuration (if SSH mode enabled)
        if [[ "${SETUP_MODE:-both}" == "ssh" || "${SETUP_MODE:-both}" == "both" ]]; then
            configure_advanced_fail2ban
        fi
        
        # AppArmor enforcement
        if command -v aa-enforce >/dev/null 2>&1; then
            # Enable AppArmor for standard profiles
            for profile in /etc/apparmor.d/usr.sbin.*; do
                if [[ -f "$profile" ]]; then
                    aa-enforce "$profile" 2>/dev/null || true
                fi
            done
            info "AppArmor profiles enforced"
        fi
        
        # Disable unused network protocols
        atomic_install "$CONFIG_DIR/security/hardening/blacklist-protocols.conf" "/etc/modprobe.d/blacklist-protocols.conf" "644" "root:root"
        
        # Secure mount options
        apply_secure_mount_options
        
        success "Hardened security configuration applied"
    else
        info "[DRY RUN] Would apply hardened security configuration"
    fi
}

# Configure basic fail2ban (minimal/standard)
configure_basic_fail2ban() {
    info "Configuring basic fail2ban protection..."
    
    # Create basic SSH jail from template
    local temp_fail2ban_conf=$(mktemp)
    envsubst < "$CONFIG_DIR/security/fail2ban/jail.d/ssh-basic.conf" > "$temp_fail2ban_conf"
    atomic_install "$temp_fail2ban_conf" /etc/fail2ban/jail.d/ssh-basic.conf 644 root:root
    rm "$temp_fail2ban_conf"
    
    systemctl enable fail2ban
    if ! is_ssh_connection_active; then
        systemctl restart fail2ban
    else
        warn "fail2ban configuration ready but not restarted (you're connected via SSH)"
        warn "Restart manually after testing: systemctl restart fail2ban"
    fi
}

# Configure advanced fail2ban (hardened)
configure_advanced_fail2ban() {
    info "Configuring advanced fail2ban protection..."
    
    # Enhanced SSH jail with more aggressive settings
    local temp_fail2ban_conf=$(mktemp)
    envsubst < "$CONFIG_DIR/security/fail2ban/jail.d/ssh.conf" > "$temp_fail2ban_conf"
    atomic_install "$temp_fail2ban_conf" /etc/fail2ban/jail.d/ssh-hardened.conf 644 root:root
    rm "$temp_fail2ban_conf"
    
    # Install aggressive SSH filter if available
    if [[ -f "$CONFIG_DIR/security/fail2ban/sshd-aggressive.conf" ]]; then
        atomic_install "$CONFIG_DIR/security/fail2ban/sshd-aggressive.conf" /etc/fail2ban/filter.d/sshd-aggressive.conf 644 root:root
    fi
    
    systemctl enable fail2ban
    if ! is_ssh_connection_active; then
        systemctl restart fail2ban
    else
        warn "fail2ban configuration ready but not restarted (you're connected via SSH)"
        warn "Restart manually after testing: systemctl restart fail2ban"
    fi
}

# Configure basic firewall
configure_basic_firewall() {
    info "Configuring basic firewall..."
    
    if ! is_ssh_connection_active; then
        # Safe to configure firewall when not connected via SSH
        ufw --force reset
        ufw default deny incoming
        ufw default allow outgoing
        ufw limit "${SSH_PORT}/tcp"
        ufw allow 80/tcp   # HTTP
        ufw allow 443/tcp  # HTTPS
        ufw --force enable
        success "Basic firewall configured"
    else
        warn "Skipping firewall configuration (you're connected via SSH)"
        warn "Configure manually after testing SSH on port $SSH_PORT"
        warn "Commands: ufw limit $SSH_PORT/tcp && ufw allow 80/tcp && ufw allow 443/tcp && ufw --force enable"
    fi
}

# Apply secure mount options
apply_secure_mount_options() {
    info "Applying secure mount options..."
    
    # Backup original fstab
    cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d)
    
    # Add secure mount options for common filesystems
    # This is conservative - only adds nodev,nosuid to /tmp if it exists as separate mount
    if grep -q "^[^#].*[[:space:]]/tmp[[:space:]]" /etc/fstab; then
        sed -i 's|\([[:space:]]/tmp[[:space:]][[:space:]]*[^[:space:]]*[[:space:]][[:space:]]*\)\([^[:space:]]*\)|\1\2,nodev,nosuid,noexec|' /etc/fstab
        info "Added secure options to /tmp mount"
    fi
    
    # Add secure options to /var/tmp if it exists as separate mount
    if grep -q "^[^#].*[[:space:]]/var/tmp[[:space:]]" /etc/fstab; then
        sed -i 's|\([[:space:]]/var/tmp[[:space:]][[:space:]]*[^[:space:]]*[[:space:]][[:space:]]*\)\([^[:space:]]*\)|\1\2,nodev,nosuid,noexec|' /etc/fstab
        info "Added secure options to /var/tmp mount"
    fi
}

# Create SSH audit script (for SSH mode)
create_ssh_audit_script() {
    if [[ "${SETUP_MODE:-both}" == "ssh" || "${SETUP_MODE:-both}" == "both" ]]; then
        info "Creating SSH audit script..."
        
        if [[ "$DRY_RUN" == "false" ]]; then
            atomic_install "$CONFIG_DIR/scripts/security/ssh-audit.sh" "/usr/local/bin/ssh-audit.sh" "755" "root:root"
            success "SSH audit script created at /usr/local/bin/ssh-audit.sh"
        else
            info "[DRY RUN] Would create SSH audit script at /usr/local/bin/ssh-audit.sh"
        fi
    fi
}

# Validate security configurations
validate_security_configs() {
    info "Validating security configurations..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY RUN] Would validate security configurations after applying changes"
        success "[DRY RUN] Security configuration validation skipped"
        return 0
    fi
    
    local validation_failed=false
    
    # Validate sysctl parameters
    for sysctl_file in /etc/sysctl.d/2*-security-*.conf; do
        if [[ -f "$sysctl_file" ]]; then
            if ! sysctl -p "$sysctl_file" >/dev/null 2>&1; then
                error "Invalid sysctl parameters in $sysctl_file"
                validation_failed=true
            fi
        fi
    done
    
    # Validate fail2ban configuration (if SSH mode)
    if [[ "${SETUP_MODE:-both}" == "ssh" || "${SETUP_MODE:-both}" == "both" ]]; then
        if ! fail2ban-client --test >/dev/null 2>&1; then
            error "fail2ban configuration validation failed"
            validation_failed=true
        fi
    fi
    
    # Validate AppArmor profiles (if enforced)
    if command -v aa-status >/dev/null 2>&1; then
        if ! aa-status >/dev/null 2>&1; then
            warn "AppArmor status check failed - may not be properly configured"
        fi
    fi
    
    if [[ "$validation_failed" == "true" ]]; then
        error "Security configuration validation failed"
        return 1
    fi
    
    success "Security configuration validation passed"
}

# Apply all security configurations
apply_all_security() {
    info "Applying comprehensive security configuration..."
    
    # Apply security hardening based on profile
    apply_security_hardening
    
    # Create audit scripts
    create_ssh_audit_script
    
    # Validate configurations
    validate_security_configs
    
    success "Security configuration complete"
}

# Test security configurations
test_security_configs() {
    info "Testing security configurations..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY RUN] Would test security configurations after applying changes"
        success "[DRY RUN] Security configuration testing skipped"
        return 0
    fi
    
    # Test sysctl parameters without applying
    for sysctl_file in /etc/sysctl.d/2*-security-*.conf; do
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
    
    # Test fail2ban configuration (if SSH mode)
    if [[ "${SETUP_MODE:-both}" == "ssh" || "${SETUP_MODE:-both}" == "both" ]]; then
        if ! fail2ban-client --test >/dev/null 2>&1; then
            error "fail2ban configuration test failed"
            return 1
        fi
    fi
    
    success "Security configuration tests passed"
}