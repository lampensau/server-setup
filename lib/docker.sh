#!/bin/bash

# Docker Profile Library - Maximum Security Configuration
# Provides hardened Docker + Coolify setup as server profile

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Docker version requirements
readonly MIN_DOCKER_VERSION="27.1.1"

# Docker Profile Main Function
apply_docker_profile_complete() {
    info "Applying Docker server profile with maximum security hardening"
    
    # Pre-flight checks
    check_docker_prerequisites
    
    # Core Docker installation and hardening
    install_docker_ce_hardened
    configure_docker_daemon_security
    setup_docker_user_namespaces
    apply_cve_2024_41110_mitigations
    
    # Container security
    configure_apparmor_docker_profiles
    setup_seccomp_profiles
    configure_docker_networks
    
    # Coolify installation (default for Docker profile)
    install_coolify_hardened
    configure_coolify_security
    
    # Monitoring and compliance
    setup_docker_monitoring
    configure_docker_audit
    
    info "Docker profile configuration complete"
}

# Pre-flight checks for Docker installation
check_docker_prerequisites() {
    info "Checking Docker installation prerequisites"
    
    # Check available disk space (Docker needs at least 10GB)
    local available_space
    available_space=$(df /var/lib 2>/dev/null | tail -1 | awk '{print $4}')
    if [[ -n "$available_space" && "$available_space" -lt 10485760 ]]; then
        warn "Less than 10GB available in /var/lib - Docker may have storage issues"
    fi
    
    # Check if Docker is already installed
    if command -v docker >/dev/null 2>&1; then
        local current_version
        current_version=$(docker --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
        if [[ -n "$current_version" ]]; then
            info "Docker $current_version is already installed - will upgrade if necessary"
        fi
    fi
    
    success "Prerequisites check completed"
}

# Docker CE Installation with Security
install_docker_ce_hardened() {
    info "Installing Docker CE with security hardening (minimum version: $MIN_DOCKER_VERSION)"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Remove any existing Docker installations
        apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
        
        # Install prerequisites
        apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
        
        # Add Docker's official GPG key
        curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        # Add Docker repository
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
        
        # Update package index
        apt-get update
        
        # Install latest Docker CE with required components
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        # Verify installed version meets minimum requirements
        local installed_version
        installed_version=$(docker --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
        if [[ -n "$installed_version" ]]; then
            if ! version_greater_equal "$installed_version" "$MIN_DOCKER_VERSION"; then
                error "Docker version $installed_version is vulnerable to CVE-2024-41110. Minimum required: $MIN_DOCKER_VERSION"
                return 1
            fi
            info "Docker $installed_version installed successfully"
        fi
        
        # Enable but don't start Docker service yet (we need to configure it first)
        systemctl enable docker
        systemctl enable containerd
    else
        info "[DRY RUN] Would install Docker CE $MIN_DOCKER_VERSION+ with security components"
    fi
    
    success "Docker CE installation completed"
}

# Hardened Daemon Configuration
configure_docker_daemon_security() {
    info "Configuring Docker daemon with maximum security"
    
    # Create Docker configuration directory
    if [[ "$DRY_RUN" == "false" ]]; then
        mkdir -p /etc/docker
        mkdir -p /etc/systemd/system/docker.service.d
        mkdir -p /etc/systemd/system/docker.socket.d
    fi
    
    # Select daemon configuration based on security profile
    local daemon_config_file
    case "$SECURITY_PROFILE" in
        "hardened")
            daemon_config_file="$CONFIG_DIR/docker/daemon/daemon-hardened.json"
            ;;
        *)
            daemon_config_file="$CONFIG_DIR/docker/daemon/daemon-standard.json"
            ;;
    esac
    
    # Install daemon configuration
    atomic_install "$daemon_config_file" "/etc/docker/daemon.json" "644" "root:root"
    
    # Install systemd service overrides for security
    atomic_install "$CONFIG_DIR/docker/systemd/docker.service.d/override.conf" \
                   "/etc/systemd/system/docker.service.d/override.conf" "644" "root:root"
    
    atomic_install "$CONFIG_DIR/docker/systemd/docker.socket.d/override.conf" \
                   "/etc/systemd/system/docker.socket.d/override.conf" "644" "root:root"
    
    success "Docker daemon security configuration applied"
}

# CVE-2024-41110 Specific Mitigations
apply_cve_2024_41110_mitigations() {
    info "Applying CVE-2024-41110 mitigations"
    
    # Version check is already done in install_docker_ce_hardened
    
    # Configure systemd service to use Unix socket only (no TCP)
    if [[ "$DRY_RUN" == "false" ]]; then
        # Ensure Docker daemon only listens on Unix socket
        systemctl edit docker --force --full > /dev/null 2>&1 << 'EOF'
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target docker.socket firewalld.service containerd.service time-set.target
Wants=network-online.target containerd.service
Requires=docker.socket

[Service]
Type=notify
ExecStart=/usr/bin/dockerd --host=unix:///var/run/docker.sock --containerd=/run/containerd/containerd.sock
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutStartSec=0
RestartSec=2
Restart=always
StartLimitBurst=3
StartLimitInterval=60s
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
Delegate=yes
KillMode=process
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
EOF
    else
        info "[DRY RUN] Would configure Docker service for Unix socket only"
    fi
    
    # Configure socket permissions for CVE protection
    atomic_install "$CONFIG_DIR/docker/systemd/docker.socket.d/override.conf" \
                   "/etc/systemd/system/docker.socket.d/override.conf" "644" "root:root"
    
    success "CVE-2024-41110 mitigations applied"
}

# User Namespace Configuration
setup_docker_user_namespaces() {
    info "Configuring Docker user namespaces for container isolation"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Create dockremap user for namespace remapping
        if ! id dockremap &>/dev/null; then
            useradd --system --shell /bin/false --no-create-home dockremap
            info "Created dockremap user for namespace remapping"
        fi
    else
        info "[DRY RUN] Would create dockremap user for namespace remapping"
    fi
    
    # Install subuid/subgid configuration files
    atomic_install "$CONFIG_DIR/docker/security/userns/subuid.conf" "/etc/subuid" "644" "root:root"
    atomic_install "$CONFIG_DIR/docker/security/userns/subgid.conf" "/etc/subgid" "644" "root:root"
    
    success "User namespaces configured for container isolation"
}

# AppArmor Profiles for Docker
configure_apparmor_docker_profiles() {
    info "Configuring AppArmor profiles for Docker containers"
    
    # Check if AppArmor is available
    if ! command -v apparmor_status >/dev/null 2>&1; then
        warn "AppArmor not available - skipping Docker AppArmor profiles"
        return 0
    fi
    
    # Install Docker-specific AppArmor profiles
    atomic_install "$CONFIG_DIR/docker/security/apparmor/docker-hardened.profile" \
                   "/etc/apparmor.d/docker-hardened" "644" "root:root"
    
    atomic_install "$CONFIG_DIR/docker/security/apparmor/coolify-container.profile" \
                   "/etc/apparmor.d/coolify-container" "644" "root:root"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Load the profiles
        apparmor_parser -r /etc/apparmor.d/docker-hardened
        apparmor_parser -r /etc/apparmor.d/coolify-container
    else
        info "[DRY RUN] Would load Docker AppArmor profiles"
    fi
    
    success "AppArmor profiles configured for Docker containers"
}

# Seccomp Profiles
setup_seccomp_profiles() {
    info "Setting up seccomp profiles for container syscall filtering"
    
    # Install custom seccomp profile
    atomic_install "$CONFIG_DIR/docker/security/seccomp/docker-hardened.json" \
                   "/etc/docker/seccomp-hardened.json" "644" "root:root"
    
    success "Seccomp profiles configured for syscall filtering"
}

# Docker Network Configuration
configure_docker_networks() {
    info "Configuring Docker networks with security isolation"
    
    # Install network configuration script
    atomic_install "$CONFIG_DIR/docker/networking/docker-networks.conf" \
                   "/etc/docker/networks.conf" "755" "root:root"
    
    # Create iptables rules directory if it doesn't exist
    if [[ "$DRY_RUN" == "false" ]]; then
        mkdir -p /etc/iptables/rules.d
    fi
    
    # Install additional iptables rules for Docker
    atomic_install "$CONFIG_DIR/docker/networking/iptables-docker.rules" \
                   "/etc/iptables/rules.d/docker.rules" "644" "root:root"
    
    success "Docker network security configured"
}

# Coolify Installation (Default for Docker Profile)
install_coolify_hardened() {
    info "Installing Coolify with security hardening"
    
    # Generate secure environment variables for Coolify
    if [[ "$DRY_RUN" == "false" ]]; then
        export COOLIFY_APP_ID=$(openssl rand -hex 16)
        export COOLIFY_SECRET_KEY=$(openssl rand -base64 32)
        export COOLIFY_APP_KEY="base64:$(openssl rand -base64 32)"
        export COOLIFY_DB_PASSWORD=$(openssl rand -base64 24)
        export COOLIFY_REDIS_PASSWORD=$(openssl rand -base64 24)
        export COOLIFY_DOMAIN="${DOMAIN:-localhost}"
        export COOLIFY_SSL_ENABLED="true"
    else
        # Set dummy values for dry run
        export COOLIFY_APP_ID="dummy-app-id"
        export COOLIFY_SECRET_KEY="dummy-secret-key"
        export COOLIFY_APP_KEY="base64:dummy-app-key"
        export COOLIFY_DB_PASSWORD="dummy-db-password"
        export COOLIFY_REDIS_PASSWORD="dummy-redis-password"
        export COOLIFY_DOMAIN="${DOMAIN:-localhost}"
        export COOLIFY_SSL_ENABLED="true"
    fi
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Download and run Coolify installer with our generated environment
        
        # Download and run Coolify installer
        if curl -fsSL https://cdn.coollabs.io/coolify/install.sh -o /tmp/coolify-install.sh; then
            chmod +x /tmp/coolify-install.sh
            info "Running Coolify installer with security environment..."
            if bash /tmp/coolify-install.sh; then
                info "Coolify installer completed successfully"
            else
                error "Coolify installation failed"
                rm -f /tmp/coolify-install.sh
                return 1
            fi
        else
            error "Failed to download Coolify installer"
            return 1
        fi
        
        # Verify Coolify installation
        local retry_count=0
        while [[ $retry_count -lt 30 ]]; do
            if systemctl is-active --quiet coolify 2>/dev/null; then
                success "Coolify service is running"
                break
            elif [[ -f /data/coolify/source/.env ]]; then
                info "Coolify installed but service not yet active (attempt $((retry_count + 1))/30)"
                sleep 5
                ((retry_count++))
            else
                info "Waiting for Coolify installation to complete (attempt $((retry_count + 1))/30)"
                sleep 5
                ((retry_count++))
            fi
        done
        
        if [[ $retry_count -eq 30 ]]; then
            warn "Coolify installation verification timed out - manual verification recommended"
        fi
        
        # Clean up
        rm -f /tmp/coolify-install.sh
    else
        info "[DRY RUN] Would install Coolify with secure configuration"
    fi
    
    success "Coolify installation completed with security hardening"
}

# Coolify Security Configuration
configure_coolify_security() {
    info "Configuring Coolify security settings"
    
    local coolify_env="/data/coolify/source/.env"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Wait for Coolify to be fully installed
        local retry_count=0
        while [[ ! -f "$coolify_env" && $retry_count -lt 30 ]]; do
            sleep 2
            ((retry_count++))
        done
        
        if [[ -f "$coolify_env" ]]; then
            # Apply security configurations to Coolify
            sed -i 's/APP_DEBUG=.*/APP_DEBUG=false/' "$coolify_env"
            
            # Add security settings if not present
            if ! grep -q "DB_SSL_MODE" "$coolify_env"; then
                echo "DB_SSL_MODE=require" >> "$coolify_env"
            fi
            
            if ! grep -q "SESSION_SECURE_COOKIE" "$coolify_env"; then
                echo "SESSION_SECURE_COOKIE=true" >> "$coolify_env"
                echo "SESSION_HTTP_ONLY=true" >> "$coolify_env"
                echo "SESSION_SAME_SITE=strict" >> "$coolify_env"
            fi
            
            # Install hardened Traefik configuration
            if [[ -f "$CONFIG_DIR/docker/coolify/traefik.yml.template" ]]; then
                export COOLIFY_DOMAIN="${DOMAIN:-localhost}"
                process_config_template "$CONFIG_DIR/docker/coolify/traefik.yml.template" \
                                       "/data/coolify/proxy/traefik.yml" \
                                       "COOLIFY_DOMAIN"
            fi
            
            # Restart Coolify to apply changes
            systemctl restart coolify || warn "Could not restart Coolify service"
        else
            warn "Coolify environment file not found - manual security configuration required"
        fi
    else
        info "[DRY RUN] Would configure Coolify security settings"
    fi
    
    success "Coolify security configuration applied"
}

# Docker Monitoring Setup
setup_docker_monitoring() {
    info "Setting up Docker monitoring and logging"
    
    # Install audit rules for Docker
    atomic_install "$CONFIG_DIR/docker/monitoring/audit-docker.rules" \
                   "/etc/audit/rules.d/50-docker.rules" "644" "root:root"
    
    # Install log rotation configuration
    atomic_install "$CONFIG_DIR/docker/monitoring/docker-logrotate.conf" \
                   "/etc/logrotate.d/docker" "644" "root:root"
    
    # Install Falco rules if Falco is available
    if command -v falco >/dev/null 2>&1; then
        atomic_install "$CONFIG_DIR/docker/monitoring/falco-docker.yaml" \
                       "/etc/falco/falco_rules.d/docker-security.yaml" "644" "root:root"
        info "Falco Docker security rules installed"
    else
        info "Falco not available - Docker runtime protection rules skipped"
    fi
    
    success "Docker monitoring configured"
}

# Docker Audit Configuration
configure_docker_audit() {
    info "Configuring Docker audit and compliance"
    
    # Install Docker Bench for Security if requested
    if [[ "$SECURITY_PROFILE" == "hardened" ]]; then
        if [[ "$DRY_RUN" == "false" ]]; then
            # Create a weekly cron job for Docker Bench security scan
            cat > /etc/cron.d/docker-bench-security << 'EOF'
# Weekly Docker Bench for Security scan
0 2 * * 0 root docker run --rm --net host --pid host --userns host --cap-add audit_control -v /etc:/etc:ro -v /var/lib:/var/lib:ro -v /var/run/docker.sock:/var/run/docker.sock:ro docker/docker-bench-security > /var/log/docker-bench-$(date +\%Y\%m\%d).log 2>&1
EOF
            chmod 644 /etc/cron.d/docker-bench-security
        else
            info "[DRY RUN] Would install weekly Docker Bench security scan"
        fi
    fi
    
    success "Docker audit and compliance configured"
}

# Start Docker services
start_docker_services() {
    info "Starting Docker services"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Reload systemd configuration
        systemctl daemon-reload
        
        # Start Docker services
        systemctl start docker
        systemctl start containerd
        
        # Verify Docker is running
        if systemctl is-active --quiet docker; then
            success "Docker services started successfully"
        else
            error "Failed to start Docker services"
            return 1
        fi
        
        # Create secure Docker networks
        info "Creating secure Docker networks..."
        if [[ -x /etc/docker/networks.conf ]]; then
            bash /etc/docker/networks.conf || warn "Some Docker networks may not have been created"
        fi
        
        # Test Docker installation
        info "Testing Docker installation..."
        if timeout 60s docker run --rm hello-world >/dev/null 2>&1; then
            success "Docker installation verified"
        else
            warn "Docker test failed - manual verification required"
            warn "This may be due to user namespace remapping - Docker functionality may still work"
        fi
    else
        info "[DRY RUN] Would start Docker services and verify installation"
    fi
}

# Test Docker configuration
test_docker_config() {
    info "Testing Docker configuration"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        local test_failures=0
        
        # Test Docker daemon availability
        if ! docker info >/dev/null 2>&1; then
            error "Docker daemon is not accessible"
            ((test_failures++))
            return 1
        fi
        
        # Test daemon configuration
        local daemon_config
        daemon_config=$(docker info --format '{{json .}}' 2>/dev/null)
        
        if echo "$daemon_config" | grep -q "userns"; then
            success "✓ User namespace remapping is active"
        else
            warn "⚠ User namespace remapping may not be active"
            ((test_failures++))
        fi
        
        if echo "$daemon_config" | grep -q "live-restore"; then
            success "✓ Live restore is enabled"
        else
            warn "⚠ Live restore not detected"
        fi
        
        # Test security features
        if timeout 30s docker run --rm --security-opt no-new-privileges:true alpine:latest echo "Security test passed" >/dev/null 2>&1; then
            success "✓ Container security options working"
        else
            warn "⚠ Container security options test failed"
            ((test_failures++))
        fi
        
        # Test Docker networks
        local expected_networks=("dmz-network" "app-network" "data-network" "coolify-network")
        for network in "${expected_networks[@]}"; do
            if docker network ls --format '{{.Name}}' | grep -q "^${network}$"; then
                success "✓ Network ${network} exists"
            else
                warn "⚠ Network ${network} not found"
            fi
        done
        
        # Test Coolify status
        if systemctl is-active --quiet coolify 2>/dev/null; then
            success "✓ Coolify service is running"
        elif [[ -f /data/coolify/source/.env ]]; then
            warn "⚠ Coolify installed but service not active"
        else
            warn "⚠ Coolify not detected"
        fi
        
        # Summary
        if [[ $test_failures -eq 0 ]]; then
            success "Docker configuration tests passed"
        else
            warn "Docker configuration has $test_failures potential issues"
        fi
    else
        info "[DRY RUN] Would test Docker configuration and security features"
    fi
}

# Show Docker status
show_docker_status() {
    info "=== Docker Status ==="
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Docker version and CVE protection
        if command -v docker >/dev/null 2>&1; then
            local docker_version
            docker_version=$(docker --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
            echo "Docker version: ${docker_version:-Unknown}"
            if [[ -n "$docker_version" ]] && version_greater_equal "$docker_version" "$MIN_DOCKER_VERSION"; then
                echo "CVE-2024-41110: ✓ Protected (version ≥ $MIN_DOCKER_VERSION)"
            else
                echo "CVE-2024-41110: ⚠ Potentially vulnerable"
            fi
        fi
        
        # Service status
        echo "Docker service: $(systemctl is-active docker 2>/dev/null || echo 'inactive')"
        echo "Containerd service: $(systemctl is-active containerd 2>/dev/null || echo 'inactive')"
        
        # Coolify status and URL
        if systemctl list-unit-files | grep -q coolify; then
            local coolify_status
            coolify_status=$(systemctl is-active coolify 2>/dev/null || echo 'inactive')
            echo "Coolify service: $coolify_status"
            
            if [[ "$coolify_status" == "active" ]]; then
                local coolify_domain="${DOMAIN:-localhost}"
                if [[ "$coolify_domain" == "localhost" ]]; then
                    echo "Coolify URL: http://localhost:8000"
                    echo "Note: Configure DOMAIN variable for HTTPS access"
                else
                    echo "Coolify URL: https://$coolify_domain"
                fi
            fi
        else
            echo "Coolify: Not installed"
        fi
        
        # Security features
        if docker info >/dev/null 2>&1; then
            echo ""
            echo "Security Configuration:"
            
            # User namespaces
            if docker info --format '{{json .}}' 2>/dev/null | grep -q "userns"; then
                echo "  User namespaces: ✓ Enabled"
            else
                echo "  User namespaces: ⚠ Not detected"
            fi
            
            # Live restore
            if docker info --format '{{json .}}' 2>/dev/null | grep -q "live-restore"; then
                echo "  Live restore: ✓ Enabled"
            else
                echo "  Live restore: ⚠ Disabled"
            fi
            
            # Security options
            local security_opts
            security_opts=$(docker info --format '{{json .SecurityOptions}}' 2>/dev/null | jq -r '.[]' 2>/dev/null | tr '\n' ' ')
            if [[ -n "$security_opts" ]]; then
                echo "  Security options: $security_opts"
            fi
        fi
        
        # Network summary
        if command -v docker >/dev/null 2>&1 && docker network ls >/dev/null 2>&1; then
            local network_count
            network_count=$(docker network ls --format '{{.Name}}' | grep -E '^(dmz|app|data|coolify)-network$' | wc -l)
            echo "Custom networks: $network_count/4 configured"
        fi
    else
        echo "[DRY RUN] Docker status information would be displayed here"
    fi
}