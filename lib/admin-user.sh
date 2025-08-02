#!/bin/bash

# Admin user creation and configuration functions for the Unified Server Setup Framework

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Prompt for admin username if not provided
prompt_admin_username() {
    local default_username="admin"
    
    if [[ -z "${ADMIN_USER}" ]]; then
        echo ""
        read -p "Enter admin username (default: $default_username): " input_username
        ADMIN_USER="${input_username:-$default_username}"
        export ADMIN_USER
    fi
    
    # Validate username format
    if [[ ! "$ADMIN_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        error "Invalid username format: $ADMIN_USER"
        error "Username must start with a letter or underscore, contain only lowercase letters, numbers, underscores, and hyphens"
        exit 1
    fi
    
    # Check if user already exists
    if id "$ADMIN_USER" &>/dev/null; then
        warn "User $ADMIN_USER already exists - will configure existing user"
    fi
    
    info "Admin user: $ADMIN_USER"
}

# Configure admin user password
configure_admin_password() {
    info "Configuring admin user password..."
    
    if [[ "$ADMIN_PASSWORD_PROMPT" == "true" ]]; then
        if [[ "$DRY_RUN" == "false" ]]; then
            echo ""
            info "Setting password for admin user: $ADMIN_USER"
            warn "This password is for sudo access only - SSH will remain key-only!"
            warn "Use a strong password - this account has administrative privileges!"
            
            # Prompt for password with confirmation
            if passwd "$ADMIN_USER"; then
                success "Password set for admin user: $ADMIN_USER (sudo access only)"
            else
                error "Failed to set password for admin user"
                return 1
            fi
        else
            info "[DRY RUN] Would prompt for admin user password (for sudo access)"
        fi
    else
        if [[ "$DRY_RUN" == "false" ]]; then
            # Lock password - no password-based authentication at all
            passwd -l "$ADMIN_USER"
            warn "Admin user has no password - sudo will not work!"
            warn "Either use --admin-password flag or set password manually later"
            info "SSH access will be key-only"
        else
            info "[DRY RUN] Would lock admin user password (no sudo access without manual password setup)"
        fi
    fi
}

# Create admin user with secure defaults
create_admin_user() {
    info "Creating admin user: $ADMIN_USER"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Create user if it doesn't exist
        if ! id "$ADMIN_USER" &>/dev/null; then
            # Create user with home directory and bash shell
            useradd -m -s /bin/bash -c "System Administrator" "$ADMIN_USER"
            success "Admin user $ADMIN_USER created"
        else
            info "User $ADMIN_USER already exists - configuring existing user"
        fi
        
        # Ensure user has proper shell and home directory
        usermod -s /bin/bash "$ADMIN_USER"
        
        # Create home directory if it doesn't exist
        local admin_home="/home/$ADMIN_USER"
        if [[ ! -d "$admin_home" ]]; then
            mkdir -p "$admin_home"
            chown "$ADMIN_USER:$ADMIN_USER" "$admin_home"
            chmod 755 "$admin_home"
        fi
        
        # Configure password
        configure_admin_password
        
    else
        info "[DRY RUN] Would create admin user: $ADMIN_USER"
        if [[ "$ADMIN_PASSWORD_PROMPT" == "true" ]]; then
            info "[DRY RUN] Would prompt for admin user password"
        else
            info "[DRY RUN] Would configure admin user for key-only authentication"
        fi
    fi
}

# Add admin user to necessary groups
configure_admin_groups() {
    info "Configuring admin user groups..."
    
    local groups_to_add=("sudo" "adm" "systemd-journal")
    
    # Add docker group if it exists (common on systems with Docker)
    if getent group docker >/dev/null 2>&1; then
        groups_to_add+=("docker")
    fi
    
    # Add additional security groups if they exist
    for group in "ssh-users" "wheel"; do
        if getent group "$group" >/dev/null 2>&1; then
            groups_to_add+=("$group")
        fi
    done
    
    if [[ "$DRY_RUN" == "false" ]]; then
        for group in "${groups_to_add[@]}"; do
            if getent group "$group" >/dev/null 2>&1; then
                usermod -a -G "$group" "$ADMIN_USER"
                info "Added $ADMIN_USER to group: $group"
            else
                warn "Group $group does not exist - skipping"
            fi
        done
        
        success "Admin user groups configured"
    else
        info "[DRY RUN] Would add $ADMIN_USER to groups: ${groups_to_add[*]}"
    fi
}

# Set up admin user SSH directory and authorized keys
setup_admin_ssh_directory() {
    local admin_home="/home/$ADMIN_USER"
    local ssh_dir="$admin_home/.ssh"
    
    info "Setting up SSH directory for admin user..."
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Create .ssh directory structure
        mkdir -p "$ssh_dir"/{controlmasters,keys}
        
        # Set proper ownership and permissions
        chown -R "$ADMIN_USER:$ADMIN_USER" "$ssh_dir"
        chmod 700 "$ssh_dir"
        
        success "SSH directory structure created for $ADMIN_USER"
    else
        info "[DRY RUN] Would create SSH directory structure for $ADMIN_USER"
    fi
}

# Copy admin public key from config directory
install_admin_public_key() {
    local admin_home="/home/$ADMIN_USER"
    local ssh_dir="$admin_home/.ssh"
    local authorized_keys="$ssh_dir/authorized_keys"
    
    info "Installing admin public key..."
    
    # Look for admin public key in config directory
    local admin_key_file=""
    local possible_keys=(
        "$CONFIG_DIR/ssh/keys/admin.pub"
        "$CONFIG_DIR/ssh/keys/${ADMIN_USER}.pub"
        "$CONFIG_DIR/ssh/keys/admin_rsa.pub"
        "$CONFIG_DIR/ssh/keys/admin_ed25519.pub"
    )
    
    for key_file in "${possible_keys[@]}"; do
        if [[ -f "$key_file" ]]; then
            admin_key_file="$key_file"
            break
        fi
    done
    
    if [[ -n "$admin_key_file" ]]; then
        if [[ "$DRY_RUN" == "false" ]]; then
            # Install the public key
            cp "$admin_key_file" "$authorized_keys"
            chown "$ADMIN_USER:$ADMIN_USER" "$authorized_keys"
            chmod 600 "$authorized_keys"
            
            success "Admin public key installed from: $admin_key_file"
        else
            info "[DRY RUN] Would install admin public key from: $admin_key_file"
        fi
    else
        warn "No admin public key found in config directory"
        warn "Checked locations: ${possible_keys[*]}"
        warn "Admin user will need a public key added manually for SSH access"
    fi
}

# Generate new SSH key pair for admin user
generate_admin_ssh_keys() {
    local admin_home="/home/$ADMIN_USER"
    local ssh_dir="$admin_home/.ssh"
    local key_file="$ssh_dir/id_ed25519"
    
    info "Generating SSH key pair for admin user..."
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Generate ED25519 key pair if it doesn't exist
        if [[ ! -f "$key_file" ]]; then
            sudo -u "$ADMIN_USER" ssh-keygen -t ed25519 -a 100 -f "$key_file" -N "" -C "$ADMIN_USER@$(hostname)-$(date +%Y)"
            
            # Set proper permissions
            chmod 600 "$key_file"
            chmod 644 "$key_file.pub"
            chown "$ADMIN_USER:$ADMIN_USER" "$key_file" "$key_file.pub"
            
            success "SSH key pair generated for $ADMIN_USER"
            info "Public key location: $key_file.pub"
        else
            info "SSH key pair already exists for $ADMIN_USER"
        fi
    else
        info "[DRY RUN] Would generate SSH key pair for $ADMIN_USER"
    fi
}

# Apply hardened SSH client configuration to admin user
configure_admin_ssh_client() {
    local admin_home="/home/$ADMIN_USER"
    local ssh_config="$admin_home/.ssh/config"
    
    info "Configuring hardened SSH client for admin user..."
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Use the existing SSH client configuration template
        if [[ -f "$CONFIG_DIR/ssh/client/ssh-client.conf" ]]; then
            # Process template with admin user variables
            export SSH_USER="$ADMIN_USER"
            export SSH_HOME="$admin_home"
            process_config_template "$CONFIG_DIR/ssh/client/ssh-client.conf" "$ssh_config" "SSH_USER SSH_HOME"
            
            # Set proper permissions
            chown "$ADMIN_USER:$ADMIN_USER" "$ssh_config"
            chmod 600 "$ssh_config"
            
            success "Hardened SSH client configuration applied for $ADMIN_USER"
        else
            error "SSH client configuration template not found: $CONFIG_DIR/ssh/client/ssh-client.conf"
            warn "Admin user will not have optimized SSH client configuration"
            return 1
        fi
    else
        info "[DRY RUN] Would configure hardened SSH client for $ADMIN_USER using existing template"
    fi
}

# Configure sudo access for admin user
configure_admin_sudo() {
    info "Configuring sudo access for admin user..."
    
    local sudoers_file="/etc/sudoers.d/90-admin-$ADMIN_USER"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Check if sudoers file already exists
        if [[ -f "$sudoers_file" ]]; then
            warn "Sudoers file already exists: $sudoers_file"
            local backup_file="${sudoers_file}.backup.$(date +%Y%m%d-%H%M%S)"
            cp "$sudoers_file" "$backup_file"
            info "Created backup: $backup_file"
        fi
        
        # Create or update sudoers configuration template file
        local temp_sudoers=$(mktemp)
        cat > "$temp_sudoers" << EOF
# Sudo configuration for admin user: $ADMIN_USER
# Generated by server-setup script on $(date)
EOF

        if [[ "$ADMIN_PASSWORD_PROMPT" == "true" ]]; then
            # Password-based sudo access (standard security practice)
            cat >> "$temp_sudoers" << EOF

# Allow admin user full sudo access with password authentication
$ADMIN_USER ALL=(ALL:ALL) ALL

# Some read-only operations without password for convenience
$ADMIN_USER ALL=(root) NOPASSWD: /bin/systemctl status *, /bin/journalctl -f, /usr/local/bin/ssh-audit.sh
EOF
            info "Sudo configured with password authentication (recommended)"
        else
            # No sudo configuration if no password is set
            cat >> "$temp_sudoers" << EOF

# Admin user needs password for sudo access
# Run: sudo passwd $ADMIN_USER
# Then uncomment the line below:
# $ADMIN_USER ALL=(ALL:ALL) ALL
EOF
            warn "Sudo access not configured - admin user has no password!"
            warn "Set password with: sudo passwd $ADMIN_USER"
        fi
        
        # Validate sudoers file before installing
        if visudo -c -f "$temp_sudoers"; then
            # Install the validated sudoers file atomically
            atomic_install "$temp_sudoers" "$sudoers_file" "440" "root:root"
            success "Sudo configuration created for $ADMIN_USER"
        else
            error "Invalid sudoers configuration - not installing"
            rm -f "$temp_sudoers"
            return 1
        fi
        
        # Clean up temp file
        rm -f "$temp_sudoers"
    else
        info "[DRY RUN] Would configure sudo access for $ADMIN_USER"
        if [[ -f "$sudoers_file" ]]; then
            info "[DRY RUN] Would backup existing sudoers file: $sudoers_file"
        fi
    fi
}

# Set up admin user bash environment
configure_admin_environment() {
    local admin_home="/home/$ADMIN_USER"
    
    info "Configuring admin user environment..."
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Create basic .bashrc if it doesn't exist
        if [[ ! -f "$admin_home/.bashrc" ]]; then
            cp /etc/skel/.bashrc "$admin_home/.bashrc"
            chown "$ADMIN_USER:$ADMIN_USER" "$admin_home/.bashrc"
        fi
        
        # Add useful aliases and functions for admin work
        cat >> "$admin_home/.bashrc" << 'EOF'

# Server administration aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'

# System monitoring aliases
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias ps='ps aux'
alias top='htop 2>/dev/null || top'

# Log viewing aliases
alias logs='sudo journalctl -f'
alias syslog='sudo tail -f /var/log/syslog'
alias authlog='sudo tail -f /var/log/auth.log'

# SSH audit shortcut
alias ssh-audit='sudo /usr/local/bin/ssh-audit.sh 2>/dev/null || echo "SSH audit script not available"'

# Safety aliases
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Admin functions
systemd-status() {
    echo "=== System Services Status ==="
    sudo systemctl --type=service --state=running --no-pager -l
}

security-check() {
    echo "=== Security Status Check ==="
    echo "Failed login attempts:"
    sudo grep "Failed password" /var/log/auth.log | tail -5
    echo ""
    echo "Last successful logins:"
    lastlog | head -10
}
EOF
        
        # Set proper ownership
        chown "$ADMIN_USER:$ADMIN_USER" "$admin_home/.bashrc"
        
        success "Admin user environment configured"
    else
        info "[DRY RUN] Would configure admin user environment"
    fi
}

# Test admin user configuration
test_admin_user_config() {
    info "Testing admin user configuration..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY RUN] Would test admin user configuration after applying changes"
        success "[DRY RUN] Admin user configuration testing skipped"
        return 0
    fi
    
    local admin_home="/home/$ADMIN_USER"
    local ssh_dir="$admin_home/.ssh"
    
    # Test user exists
    if ! id "$ADMIN_USER" &>/dev/null; then
        error "Admin user $ADMIN_USER does not exist"
        return 1
    fi
    
    # Test sudo access
    if ! groups "$ADMIN_USER" | grep -q sudo; then
        error "Admin user $ADMIN_USER is not in sudo group"
        return 1
    fi
    
    # Test SSH directory permissions
    if [[ -d "$ssh_dir" ]]; then
        local ssh_perms=$(stat -c "%a" "$ssh_dir")
        if [[ "$ssh_perms" != "700" ]]; then
            error "SSH directory has incorrect permissions: $ssh_perms (should be 700)"
            return 1
        fi
    fi
    
    # Test SSH key exists
    if [[ -f "$ssh_dir/id_ed25519" ]]; then
        local key_perms=$(stat -c "%a" "$ssh_dir/id_ed25519")
        if [[ "$key_perms" != "600" ]]; then
            error "SSH private key has incorrect permissions: $key_perms (should be 600)"
            return 1
        fi
    fi
    
    # Test authorized_keys if it exists
    if [[ -f "$ssh_dir/authorized_keys" ]]; then
        local auth_keys_perms=$(stat -c "%a" "$ssh_dir/authorized_keys")
        if [[ "$auth_keys_perms" != "600" ]]; then
            error "authorized_keys has incorrect permissions: $auth_keys_perms (should be 600)"
            return 1
        fi
    fi
    
    success "Admin user configuration tests passed"
}

# Display admin user status
show_admin_user_status() {
    info "=== Admin User Status for $ADMIN_USER ==="
    
    if id "$ADMIN_USER" &>/dev/null; then
        echo "User exists: Yes"
        echo "Home directory: /home/$ADMIN_USER"
        echo "Shell: $(getent passwd "$ADMIN_USER" | cut -d: -f7)"
        echo "Groups: $(groups "$ADMIN_USER" | cut -d: -f2-)"
        echo ""
        
        # SSH key information
        local admin_home="/home/$ADMIN_USER"
        if [[ -f "$admin_home/.ssh/id_ed25519.pub" ]]; then
            echo "SSH Key:"
            echo "$(ssh-keygen -lf "$admin_home/.ssh/id_ed25519.pub")"
        else
            echo "SSH Key: Not found"
        fi
        echo ""
        
        # Authorized keys
        if [[ -f "$admin_home/.ssh/authorized_keys" ]]; then
            local key_count=$(wc -l < "$admin_home/.ssh/authorized_keys")
            echo "Authorized keys: $key_count key(s)"
        else
            echo "Authorized keys: Not configured"
        fi
        echo ""
        
        # Password status
        if passwd -S "$ADMIN_USER" 2>/dev/null | grep -q " L "; then
            echo "Password: Locked (key-only access)"
        elif passwd -S "$ADMIN_USER" 2>/dev/null | grep -q " P "; then
            echo "Password: Set"
        else
            echo "Password: Unknown status"
        fi
        echo ""
        
        # Sudo configuration
        if [[ -f "/etc/sudoers.d/90-admin-$ADMIN_USER" ]]; then
            echo "Sudo configuration: Present"
        else
            echo "Sudo configuration: Not found"
        fi
    else
        echo "User exists: No"
    fi
}

# Complete admin user setup
setup_admin_user_complete() {
    info "Setting up admin user..."
    
    # Prompt for username if not provided
    prompt_admin_username
    
    # Create the user
    create_admin_user
    
    # Configure groups
    configure_admin_groups
    
    # Set up SSH
    setup_admin_ssh_directory
    install_admin_public_key
    generate_admin_ssh_keys
    configure_admin_ssh_client
    
    # Configure sudo access
    configure_admin_sudo
    
    # Set up environment
    configure_admin_environment
    
    # Test configuration
    test_admin_user_config
    
    success "Admin user setup complete for: $ADMIN_USER"
}