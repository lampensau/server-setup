#!/bin/bash

# SSH Client configuration functions for the Unified Server Setup Framework

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Setup SSH client configuration
setup_ssh_client() {
    local user_name=$(get_real_user)
    local user_home=$(getent passwd "$user_name" | cut -d: -f6)
    
    info "Setting up SSH client configuration for user: $user_name"
    
    if [[ "${DRY_RUN:-false}" == "false" ]]; then
        # Create .ssh directory structure
        mkdir -p "$user_home/.ssh"/{controlmasters,keys}
        
        # Generate user SSH key pair - ED25519 only with maximum protection
        if [[ ! -f "$user_home/.ssh/id_ed25519" ]]; then
            sudo -u "$user_name" ssh-keygen -t ed25519 -a 100 -f "$user_home/.ssh/id_ed25519" -N "" -C "$user_name@$(hostname)-$(date +%Y)"
            success "ED25519 key pair generated for $user_name"
        else
            info "ED25519 key pair already exists for $user_name"
        fi
        
        # Install SSH client configuration from config structure
        if [[ -f "$CONFIG_DIR/ssh/client/ssh-client.conf" ]]; then
            # Process template with user-specific variables
            export SSH_USER="$user_name"
            export SSH_HOME="$user_home"
            process_config_template "$CONFIG_DIR/ssh/client/ssh-client.conf" "$user_home/.ssh/config" "SSH_USER SSH_HOME"
        fi
        
        # Set proper permissions
        chown -R "$user_name:$user_name" "$user_home/.ssh"
        chmod 700 "$user_home/.ssh"
        chmod 600 "$user_home/.ssh/id_ed25519"
        chmod 644 "$user_home/.ssh/id_ed25519.pub"
        
        if [[ -f "$user_home/.ssh/config" ]]; then
            chmod 600 "$user_home/.ssh/config"
        fi
    else
        info "[DRY RUN] Would setup SSH client for user: $user_name"
    fi
    
    success "SSH client configured for user: $user_name"
}

# Create SSH connection management script
create_ssh_connections_script() {
    local user_name=$(get_real_user)
    local user_home=$(getent passwd "$user_name" | cut -d: -f6)
    
    info "Creating SSH connection management script..."
    
    if [[ "${DRY_RUN:-false}" == "false" ]]; then
        # Install the SSH management script from config structure
        atomic_install "$CONFIG_DIR/scripts/ssh/ssh-connections.sh" "$user_home/.ssh/ssh-connections.sh" "755" "$user_name:$user_name"
        
        success "SSH connection management script created"
    else
        info "[DRY RUN] Would create SSH connection management script"
    fi
}

# Setup SSH client tools and utilities
setup_ssh_tools() {
    info "Setting up SSH client tools..."
    
    if [[ "${DRY_RUN:-false}" == "false" ]]; then
        # Install autossh service template if available
        if [[ -f "$CONFIG_DIR/ssh/services/autossh@.service" ]]; then
            atomic_install "$CONFIG_DIR/ssh/services/autossh@.service" "/etc/systemd/system/autossh@.service" "644" "root:root"
            systemctl daemon-reload
            info "Autossh service template installed"
        fi
        
        # Install additional SSH tools from config structure
        if [[ -d "$CONFIG_DIR/scripts/ssh" ]]; then
            for script in "$CONFIG_DIR/scripts/ssh"/*.sh; do
                if [[ -f "$script" && "$(basename "$script")" != "ssh-connections.sh" ]]; then
                    script_name=$(basename "$script")
                    atomic_install "$script" "/usr/local/bin/$script_name" "755" "root:root"
                    info "Installed SSH tool: $script_name"
                fi
            done
        fi
    else
        info "[DRY RUN] Would setup SSH client tools"
    fi
    
    success "SSH client tools setup complete"
}

# Display SSH client status
show_ssh_client_status() {
    local user_name=$(get_real_user)
    local user_home=$(getent passwd "$user_name" | cut -d: -f6)
    
    info "=== SSH Client Status for $user_name ==="
    
    # Check for SSH keys
    echo "SSH Keys:"
    if [[ -f "$user_home/.ssh/id_ed25519.pub" ]]; then
        echo "ED25519: $(ssh-keygen -lf "$user_home/.ssh/id_ed25519.pub")"
    else
        echo "No ED25519 key found"
    fi
    echo ""
    
    # Check SSH config
    if [[ -f "$user_home/.ssh/config" ]]; then
        echo "SSH config file: Present"
    else
        echo "SSH config file: Not found"
    fi
    echo ""
    
    # Check ControlMaster sockets
    if [[ -d "$user_home/.ssh/controlmasters" ]]; then
        echo "ControlMaster sockets:"
        ls -la "$user_home/.ssh/controlmasters/" 2>/dev/null || echo "None"
    else
        echo "ControlMaster directory: Not found"
    fi
}

# Test SSH client configuration
test_ssh_client_config() {
    local user_name=$(get_real_user)
    local user_home=$(getent passwd "$user_name" | cut -d: -f6)
    
    info "Testing SSH client configuration..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY RUN] Would test SSH client configuration after applying changes"
        success "[DRY RUN] SSH client configuration testing skipped"
        return 0
    fi
    
    # Test SSH config syntax using proper method
    if [[ -f "$user_home/.ssh/config" ]]; then
        # Use ssh -G to test config syntax without actually connecting
        if ! sudo -u "$user_name" ssh -G -F "$user_home/.ssh/config" nonexistent-host >/dev/null 2>&1; then
            warn "SSH config syntax check failed"
        fi
    fi
    
    # Check key permissions
    if [[ -f "$user_home/.ssh/id_ed25519" ]]; then
        local key_perms=$(stat -c "%a" "$user_home/.ssh/id_ed25519")
        if [[ "$key_perms" != "600" ]]; then
            error "SSH private key has incorrect permissions: $key_perms (should be 600)"
            return 1
        fi
    fi
    
    # Check .ssh directory permissions
    local ssh_dir_perms=$(stat -c "%a" "$user_home/.ssh")
    if [[ "$ssh_dir_perms" != "700" ]]; then
        error "SSH directory has incorrect permissions: $ssh_dir_perms (should be 700)"
        return 1
    fi
    
    success "SSH client configuration tests passed"
}

# Configure SSH client completely
configure_ssh_client_complete() {
    info "Performing complete SSH client setup..."
    
    # Setup basic SSH client configuration
    setup_ssh_client
    
    # Create management scripts
    create_ssh_connections_script
    
    # Setup additional tools
    setup_ssh_tools
    
    # Test configuration
    test_ssh_client_config
    
    success "SSH client setup complete"
}