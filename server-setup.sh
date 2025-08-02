#!/bin/bash

# Unified Server Setup Script
# Combines SSH setup and system hardening functionality
# Version: 1.0 (Unified)

set -euo pipefail
IFS=$'\n\t'

# Script directory and configuration paths
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_DIR="$SCRIPT_DIR/config"
readonly LIB_DIR="$SCRIPT_DIR/lib"
readonly LOG_FILE="/var/log/server-setup.log"

# Source common functions
source "$LIB_DIR/common.sh"

# --- Helper Functions ---
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Unified server setup script combining SSH and system hardening."
    echo ""
    echo "Options:"
    echo "  -m, --mode <mode>         Setup mode: 'system', 'ssh', 'both' (default: both)"
    echo "  -t, --type <type>         Server type: 'bare', 'docker' (default: bare)"
    echo "  -s, --security <profile>  Security profile: 'minimal', 'standard', 'hardened' (default: standard)"
    echo "  -p, --ssh-port <port>     SSH port (default: 22)"
    echo "  --ssh-mode <mode>         SSH setup: 'server', 'client', 'both' (default: both)"
    echo "  -u, --admin-user <user>   Create admin user with sudo access (prompted if not specified)"
    echo "  --no-admin-password      Skip password setup (default: prompt for password)"
    echo "  -d, --dry-run            Enable dry-run mode"
    echo "  -h, --help               Display this help message"
    echo ""
    echo "Setup Modes:"
    echo "  system    - System hardening and optimization only"
    echo "  ssh       - SSH configuration and security only"
    echo "  both      - Complete server setup (system + SSH)"
    echo ""
    echo "Server Types:"
    echo "  bare      - Basic hardened server (default)"
    echo "  docker    - Docker + Coolify with maximum security"
    echo "  web       - Web server (nginx/Caddy) with CIS Level 2 compliance"
    echo ""
    echo "Security Profiles:"
    echo "  minimal   - Basic security measures only"
    echo "  standard  - Recommended security hardening (default)"
    echo "  hardened  - Maximum security with strict policies"
    echo ""
    echo "Examples:"
    echo "  # Basic server setup (bare type, default)"
    echo "  sudo $0"
    echo ""
    echo "  # Docker server with Coolify and maximum security"
    echo "  sudo $0 -t docker -s hardened"
    echo ""
    echo "  # SSH hardening only with custom port"
    echo "  sudo $0 -m ssh -p 2222"
    echo ""
    echo "  # Docker server with standard security"
    echo "  sudo $0 -t docker"
    echo ""
    echo "  # Web server with nginx and CIS compliance"
    echo "  sudo $0 -t web"
    echo ""
    echo "  # Create admin user with Docker setup"
    echo "  sudo $0 -t docker -u admin"
    echo ""
    echo "  # Dry run to see what would be changed"
    echo "  sudo $0 -t docker -d"
    exit 1
}

# --- Argument Parsing ---
SETUP_MODE="both"
SERVER_TYPE="bare"
SECURITY_PROFILE="standard"
SSH_PORT="22"
SSH_MODE="both"
ADMIN_USER=""
ADMIN_PASSWORD_PROMPT=true
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mode)
            SETUP_MODE="$2"
            shift 2
            ;;
        -t|--type)
            SERVER_TYPE="$2"
            shift 2
            ;;
        -s|--security)
            SECURITY_PROFILE="$2"
            shift 2
            ;;
        -p|--ssh-port)
            SSH_PORT="$2"
            shift 2
            ;;
        --ssh-mode)
            SSH_MODE="$2"
            shift 2
            ;;
        -u|--admin-user)
            ADMIN_USER="$2"
            shift 2
            ;;
        --no-admin-password)
            ADMIN_PASSWORD_PROMPT=false
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

# Export variables for use in library functions
export SETUP_MODE SERVER_TYPE SECURITY_PROFILE SSH_PORT SSH_MODE ADMIN_USER ADMIN_PASSWORD_PROMPT DRY_RUN
export SCRIPT_DIR CONFIG_DIR LIB_DIR LOG_FILE

# --- Main Execution ---
main() {
    # Check root privileges first, before any logging
    check_root
    
    # Initialize logging
    info "=== Unified Server Setup Started ==="
    info "Mode: $SETUP_MODE | Type: $SERVER_TYPE | Security: $SECURITY_PROFILE | SSH Port: $SSH_PORT | Dry Run: $DRY_RUN"
    
    # Pre-flight checks
    detect_os
    load_local_config
    validate_inputs
    safety_check
    display_configuration
    
    # Dependency checks
    check_dependencies
    if [[ "${SETUP_MODE:-both}" == "ssh" || "${SETUP_MODE:-both}" == "both" ]]; then
        check_openssh_version
    fi
    
    # Create backup
    create_backup
    
    # Set up error handling
    trap cleanup EXIT
    
    # Phase 1: System Preparation
    info "=== Phase 1: System Preparation ==="
    update_system
    install_required_packages
    
    # Phase 2: System Configuration (if enabled)
    if [[ "${SETUP_MODE:-both}" == "system" || "${SETUP_MODE:-both}" == "both" ]]; then
        info "=== Phase 2: System Configuration ==="
        source "$LIB_DIR/system.sh"
        apply_system_configuration
    fi
    
    # Phase 3: Security Hardening (unified)
    info "=== Phase 3: Security Hardening ==="
    source "$LIB_DIR/security.sh"
    apply_all_security
    
    # Phase 4: SSH Setup (if enabled)
    if [[ "${SETUP_MODE:-both}" == "ssh" || "${SETUP_MODE:-both}" == "both" ]]; then
        info "=== Phase 4: SSH Configuration ==="
        
        # SSH Server setup
        if [[ "${SSH_MODE:-both}" == "server" || "${SSH_MODE:-both}" == "both" ]]; then
            source "$LIB_DIR/ssh-server.sh"
            configure_ssh_server_complete
        fi
        
        # SSH Client setup
        if [[ "${SSH_MODE:-both}" == "client" || "${SSH_MODE:-both}" == "both" ]]; then
            source "$LIB_DIR/ssh-client.sh"
            configure_ssh_client_complete
        fi
    fi
    
    # Phase 5: Admin User Setup (if requested)
    if [[ -n "$ADMIN_USER" ]]; then
        info "=== Phase 5: Admin User Setup ==="
        source "$LIB_DIR/admin-user.sh"
        setup_admin_user_complete
    fi
    
    # Phase 5.5: Server Type Configuration
    if [[ "$SERVER_TYPE" == "docker" ]]; then
        info "=== Phase 5.5: Docker Server Configuration ==="
        source "$LIB_DIR/docker.sh"
        apply_docker_profile_complete
        start_docker_services
    elif [[ "$SERVER_TYPE" == "web" ]]; then
        info "=== Phase 5.5: Web Server Configuration ==="
        source "$LIB_DIR/web.sh"
        apply_web_profile_complete
        start_web_services
    fi
    
    # Phase 6: Final Configuration
    info "=== Phase 6: Final Configuration ==="
    
    # Apply pending changes if not in dry run mode
    if [[ "$DRY_RUN" == "false" ]]; then
        # Apply sysctl parameters
        sysctl --system >/dev/null 2>&1 || warn "Some sysctl parameters may not have applied"
        
        # Reload systemd configuration
        systemctl daemon-reload
        
        # Restart essential services
        systemctl restart systemd-timesyncd || warn "Failed to restart systemd-timesyncd"
        systemctl restart systemd-journald || warn "Failed to restart systemd-journald"
        systemctl restart systemd-resolved || warn "Failed to restart systemd-resolved"
    fi
    
    # Phase 7: Verification and Summary
    info "=== Phase 7: Verification ==="
    
    # Test configurations
    if [[ "${SETUP_MODE:-both}" == "system" || "${SETUP_MODE:-both}" == "both" ]]; then
        test_system_configs
    fi
    
    if [[ "${SETUP_MODE:-both}" == "ssh" || "${SETUP_MODE:-both}" == "both" ]]; then
        test_security_configs
        if [[ "${SSH_MODE:-both}" == "server" || "${SSH_MODE:-both}" == "both" ]]; then
            test_ssh_config
        fi
        if [[ "${SSH_MODE:-both}" == "client" || "${SSH_MODE:-both}" == "both" ]]; then
            test_ssh_client_config
        fi
    fi
    
    # Test admin user configuration if created
    if [[ -n "$ADMIN_USER" ]]; then
        test_admin_user_config
    fi
    
    # Test Docker configuration if Docker server type
    if [[ "$SERVER_TYPE" == "docker" ]]; then
        test_docker_config
    fi
    
    # Test web server configuration if web server type
    if [[ "$SERVER_TYPE" == "web" ]]; then
        test_web_config
    fi
    
    # Display final summary
    display_summary
    
    # Show status information
    if [[ "$DRY_RUN" == "false" ]]; then
        echo ""
        if [[ "${SETUP_MODE:-both}" == "system" || "${SETUP_MODE:-both}" == "both" ]]; then
            show_system_status
        fi
        
        if [[ "${SETUP_MODE:-both}" == "ssh" || "${SETUP_MODE:-both}" == "both" ]]; then
            echo ""
            if [[ "${SSH_MODE:-both}" == "server" || "${SSH_MODE:-both}" == "both" ]]; then
                show_ssh_status
            fi
            if [[ "${SSH_MODE:-both}" == "client" || "${SSH_MODE:-both}" == "both" ]]; then
                echo ""
                show_ssh_client_status
            fi
        fi
        
        # Show admin user status if created
        if [[ -n "$ADMIN_USER" ]]; then
            echo ""
            show_admin_user_status
        fi
        
        # Show Docker status if Docker server type
        if [[ "$SERVER_TYPE" == "docker" ]]; then
            echo ""
            show_docker_status
        fi
        
        # Show web server status if web server type
        if [[ "$SERVER_TYPE" == "web" ]]; then
            echo ""
            show_web_status
        fi
        
        # Show security audit information
        echo ""
        info "=== Security Audit Information ==="
        if [[ -x /usr/local/bin/ssh-audit.sh ]]; then
            echo "SSH audit script available: /usr/local/bin/ssh-audit.sh"
        fi
        echo "Log file: $LOG_FILE"
        echo "Backup location: $BACKUP_DIR"
        echo ""
        
        # Important reminders
        warn "=== Important Reminders ==="
        if [[ "${SETUP_MODE:-both}" == "ssh" || "${SETUP_MODE:-both}" == "both" ]]; then
            if is_ssh_connection_active; then
                warn "You are connected via SSH. Test the new configuration before disconnecting!"
                warn "Open a NEW terminal and test: ssh -p $SSH_PORT user@$(hostname -I | awk '{print $1}')"
            fi
        fi
        
        if [[ "$SECURITY_PROFILE" == "hardened" ]]; then
            warn "Hardened security profile applied - some applications may need adjustment"
        fi
        
        warn "A system reboot is recommended to ensure all changes take effect"
    fi
    
    success "=== Server Setup Complete ==="
}

# Run main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi