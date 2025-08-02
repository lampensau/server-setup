#!/bin/bash

# SSH Server configuration functions for the Unified Server Setup Framework

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Generate secure SSH host keys
generate_host_keys() {
    info "Generating secure ED25519 SSH host keys..."
    
    if [[ "${DRY_RUN:-false}" == "false" ]]; then
        # Backup existing keys
        mkdir -p /etc/ssh/backup
        cp -f /etc/ssh/ssh_host_* /etc/ssh/backup/ 2>/dev/null || true
        
        # Remove old keys (except ED25519 if it already exists and is recent)
        for key_type in rsa dsa ecdsa; do
            rm -f /etc/ssh/ssh_host_${key_type}_key*
        done
        
        # Generate ED25519 host key if it doesn't exist
        if [[ ! -f /etc/ssh/ssh_host_ed25519_key ]]; then
            ssh-keygen -t ed25519 -a 100 -f /etc/ssh/ssh_host_ed25519_key -N "" -C "$(hostname)-ed25519-$(date +%Y%m%d)"
            info "New ED25519 host key generated"
        else
            info "Existing ED25519 host key preserved"
        fi
        
        # Set proper permissions
        chmod 600 /etc/ssh/ssh_host_ed25519_key
        chmod 644 /etc/ssh/ssh_host_ed25519_key.pub
        chown root:root /etc/ssh/ssh_host_ed25519_key*
    else
        info "[DRY RUN] Would generate/verify ED25519 SSH host keys"
    fi
    
    success "SSH host keys configured"
}

# Configure SSH server with modern security
configure_ssh_server() {
    info "Configuring SSH server with modern security..."
    
    if [[ "${DRY_RUN:-false}" == "false" ]]; then
        # Backup original config
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d)
        
        # Create modular config directory
        mkdir -p /etc/ssh/sshd_config.d
        
        # Install security configuration
        local temp_security_conf=$(mktemp)
        envsubst < "$CONFIG_DIR/ssh/server/01-security.conf" > "$temp_security_conf"
        atomic_install "$temp_security_conf" /etc/ssh/sshd_config.d/01-security.conf 644 root:root
        rm "$temp_security_conf"

        # Install SFTP configuration
        atomic_install "$CONFIG_DIR/ssh/server/02-sftp.conf" /etc/ssh/sshd_config.d/02-sftp.conf 644 root:root
        
        # Update main sshd_config to include modular configs
        if ! grep -q "Include /etc/ssh/sshd_config.d/\*.conf" /etc/ssh/sshd_config; then
            # Add Include directive at the top of the config file
            sed -i '1i Include /etc/ssh/sshd_config.d/*.conf' /etc/ssh/sshd_config
        fi
        
        # Test SSH configuration before applying
        local sshd_test_output=$(sshd -T 2>&1)
        if [[ $? -ne 0 ]]; then
            error "SSH configuration test failed!"
            error "sshd -T output: $sshd_test_output"
            rollback_ssh_config $(date +%Y%m%d)
            return 1
        fi
        
        # Apply the configuration
        if ! is_ssh_connection_active; then
            systemctl restart ssh
            success "SSH server restarted with new configuration"
        else
            warn "SSH configuration updated but not restarted (you're connected via SSH)"
            warn "Test the configuration in a NEW terminal before disconnecting this session"
            warn "Command to restart: sudo systemctl restart ssh"
        fi
    else
        info "[DRY RUN] Would configure SSH server with modern security"
    fi
    
    success "SSH server configuration complete"
}

# Setup SFTP-only users (if requested)
setup_sftp_users() {
    info "Setting up SFTP-only user configuration..."
    
    if [[ "${DRY_RUN:-false}" == "false" ]]; then
        # Create SFTP group
        if ! getent group sftponly >/dev/null; then
            groupadd sftponly
            info "Created sftponly group"
        fi
        
        # Create SFTP chroot directory structure
        mkdir -p /var/sftp
        chown root:root /var/sftp
        chmod 755 /var/sftp
        
        info "SFTP infrastructure ready"
        info "To add SFTP-only user: adduser --ingroup sftponly --home /var/sftp/username --shell /bin/false username"
    else
        info "[DRY RUN] Would setup SFTP-only user infrastructure"
    fi
    
    success "SFTP setup complete"
}

# Test SSH configuration
test_ssh_config() {
    info "Testing SSH server configuration..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY RUN] Would test SSH server configuration after applying changes"
        success "[DRY RUN] SSH server configuration testing skipped"
        return 0
    fi
    
    # Test configuration syntax
    local sshd_test_output=$(sshd -T 2>&1)
    if [[ $? -ne 0 ]]; then
        error "SSH server configuration test failed!"
        error "sshd -T output: $sshd_test_output"
        return 1
    fi
    
    # Check if SSH service is running
    if ! systemctl is-active --quiet ssh; then
        warn "SSH service is not currently running"
    fi
    
    # Verify host key exists
    if [[ ! -f /etc/ssh/ssh_host_ed25519_key ]]; then
        error "ED25519 host key not found!"
        return 1
    fi
    
    # Test port configuration
    local configured_port=$(sshd -T | grep "^port " | awk '{print $2}')
    if [[ "$configured_port" != "${SSH_PORT}" ]]; then
        warn "Configured SSH port ($configured_port) doesn't match expected port (${SSH_PORT})"
    fi
    
    success "SSH server configuration tests passed"
}

# Display SSH server status
show_ssh_status() {
    info "=== SSH Server Status ==="
    
    # Service status
    echo "Service Status:"
    systemctl status ssh --no-pager -l
    echo ""
    
    # Configuration summary
    echo "Configuration Summary:"
    echo "Port: $(sshd -T | grep "^port " | awk '{print $2}')"
    echo "PermitRootLogin: $(sshd -T | grep "^permitrootlogin " | awk '{print $2}')"
    echo "PasswordAuthentication: $(sshd -T | grep "^passwordauthentication " | awk '{print $2}')"
    echo "PubkeyAuthentication: $(sshd -T | grep "^pubkeyauthentication " | awk '{print $2}')"
    echo "Protocol: $(sshd -T | grep "^protocol " | awk '{print $2}' || echo '2')"
    echo ""
    
    # Host key fingerprints
    echo "Host Key Fingerprints:"
    if [[ -f /etc/ssh/ssh_host_ed25519_key.pub ]]; then
        echo "ED25519: $(ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub)"
    fi
    echo ""
    
    # Active connections
    echo "Active SSH Connections:"
    ss -tuln | grep ":$(sshd -T | grep "^port " | awk '{print $2}' || echo 22)" || echo "None"
    echo ""
    
    # Recent connection attempts
    echo "Recent SSH Activity (last 10 entries):"
    grep "sshd" /var/log/auth.log | tail -10 || echo "No recent activity logged"
}

# Rollback SSH configuration
rollback_ssh_config() {
    local backup_date="$1"
    info "Rolling back SSH configuration..."
    
    if [[ -f "/etc/ssh/sshd_config.backup.${backup_date}" ]]; then
        cp "/etc/ssh/sshd_config.backup.${backup_date}" /etc/ssh/sshd_config
        rm -f /etc/ssh/sshd_config.d/01-security.conf
        rm -f /etc/ssh/sshd_config.d/02-sftp.conf
        
        # Test the rolled back configuration
        if sshd -T >/dev/null 2>&1; then
            systemctl restart ssh
            success "SSH configuration rolled back successfully"
        else
            error "Rolled back configuration is also invalid!"
            return 1
        fi
    else
        error "Backup file not found: /etc/ssh/sshd_config.backup.${backup_date}"
        return 1
    fi
}

# Configure SSH server completely
configure_ssh_server_complete() {
    info "Performing complete SSH server setup..."
    
    # Generate secure host keys
    generate_host_keys
    
    # Configure SSH daemon
    configure_ssh_server
    
    # Setup SFTP if requested
    if [[ "${ENABLE_SFTP:-false}" == "true" ]]; then
        setup_sftp_users
    fi
    
    # Test configuration
    test_ssh_config
    
    success "SSH server setup complete"
}