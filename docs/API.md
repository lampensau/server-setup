# Server Setup Framework API Documentation

## Overview

This document provides comprehensive API documentation for all functions in the Unified Server Setup Framework. The framework is organized into modular libraries, each focusing on specific aspects of server configuration and security hardening.

## Library Structure

### Core Libraries
- **`common.sh`** - Shared utilities, logging, validation, and error handling
- **`security.sh`** - Security hardening orchestration across SSH and system
- **`system.sh`** - System configuration (timezone, packages, services)
- **`ssh-server.sh`** - SSH daemon configuration and key management
- **`ssh-client.sh`** - SSH client configuration and optimization
- **`admin-user.sh`** - Administrative user creation and configuration

---

## common.sh - Core Utilities

### Logging Functions

#### `log(level, message)`
**Purpose**: Unified logging function with timestamp and level support  
**Parameters**:
- `level` - Log level (INFO, WARN, ERROR, SUCCESS)
- `message` - Message to log

**Usage**: Internal function, use convenience wrappers below

#### `info(message)`, `warn(message)`, `error(message)`, `success(message)`
**Purpose**: Convenience logging functions  
**Parameters**:
- `message` - Message to log

**Usage**:
```bash
info "Starting SSH configuration"
warn "This action may interrupt SSH connections"
error "Failed to restart SSH service"
success "SSH configuration completed successfully"
```

### Validation Functions

#### `validate_inputs()`
**Purpose**: Validate all global configuration variables and environment  
**Returns**: 0 on success, 1 on validation failure

**Validates**:
- Required variables are set
- SSH port range (1-65535)
- Security profile validity
- OS compatibility

#### `check_dependencies()`
**Purpose**: Verify all required system tools and packages are available  
**Returns**: 0 if all dependencies met, 1 otherwise

**Checks**:
- OpenSSH server/client packages
- System utilities (systemctl, sysctl, etc.)
- Security tools (fail2ban, ufw)

#### `check_openssh_version()`
**Purpose**: Verify OpenSSH version compatibility for modern cryptography  
**Returns**: 0 if compatible (≥7.9), 1 if too old

### Backup and Recovery Functions

#### `create_backup()`
**Purpose**: Create comprehensive backup of original configurations  
**Creates**:
- Backup directory: `/root/server-backup-TIMESTAMP/`
- Original configuration files
- Automatic restore script

#### `rollback_config(backup_dir)`
**Purpose**: Restore configurations from backup directory  
**Parameters**:
- `backup_dir` - Path to backup directory

### File Operations

#### `atomic_install(src, dest, mode, owner)`
**Purpose**: Safely install configuration files with atomic operations  
**Parameters**:
- `src` - Source file path
- `dest` - Destination file path
- `mode` - File permissions (e.g., 644, 600)
- `owner` - File owner (e.g., root:root)

#### `process_config_template(template, output, variables)`
**Purpose**: Process configuration templates with variable substitution  
**Parameters**:
- `template` - Template file path
- `output` - Output file path
- `variables` - Space-separated list of variable names

**Variables Substituted**:
- `${SSH_PORT}` - SSH port number
- `${MODERN_KEXALGORITHMS}` - Key exchange algorithms
- `${MODERN_CIPHERS}` - Encryption ciphers
- `${MODERN_MACS}` - Message authentication codes

### System Functions

#### `detect_os()`
**Purpose**: Detect operating system and version  
**Sets Global Variables**:
- `OS_NAME` - Operating system name (debian/ubuntu)
- `OS_VERSION` - Version number
- `OS_CODENAME` - Version codename

#### `update_system()`
**Purpose**: Update package lists and upgrade system packages  
**Actions**:
- `apt update`
- `apt upgrade -y`
- Package cache refresh

#### `safety_check()`
**Purpose**: Perform comprehensive pre-execution safety checks  
**Checks**:
- Root privileges
- SSH connection safety
- Disk space availability
- Service availability

---

## security.sh - Security Hardening

### Main Security Functions

#### `apply_security_hardening()`
**Purpose**: Main orchestration function for security hardening  
**Behavior**: Applies security measures based on `$SECURITY_PROFILE`

**Profiles**:
- `minimal` - Basic security measures only
- `standard` - Recommended security hardening (default)
- `hardened` - Maximum security with strict policies

#### `apply_minimal_security()`
**Purpose**: Apply basic security measures for all profiles  
**Actions**:
- Disable core dumps
- Basic kernel parameters
- Essential fail2ban configuration

#### `apply_standard_security()`
**Purpose**: Apply standard security measures (builds on minimal)  
**Actions**:
- Enhanced kernel security parameters
- Basic firewall configuration
- Process accounting
- Unattended security updates

#### `apply_hardened_security()`
**Purpose**: Apply maximum security measures (builds on standard)  
**Actions**:
- Advanced kernel hardening
- AppArmor enforcement
- Protocol blacklisting
- Secure mount options
- Advanced fail2ban rules

### Specialized Security Functions

#### `configure_basic_fail2ban()`
**Purpose**: Configure basic fail2ban protection for SSH  
**Configuration**:
- SSH jail with standard settings
- Basic ban/retry limits
- Email notifications (if configured)

#### `configure_advanced_fail2ban()`
**Purpose**: Configure advanced fail2ban with multiple jails  
**Configuration**:
- Multiple service protection
- Aggressive ban policies
- Recidive jail for repeat offenders

#### `configure_basic_firewall()`
**Purpose**: Configure basic iptables/ufw firewall rules  
**Rules**:
- Allow SSH on configured port
- Allow established connections
- Block unnecessary protocols

#### `apply_secure_mount_options()`
**Purpose**: Apply secure mount options to filesystems  
**Options**:
- `nodev`, `nosuid`, `noexec` where appropriate
- Secure `/tmp` and `/var/tmp` mounts

#### `validate_security_configs()`
**Purpose**: Validate all security configurations before application  
**Validates**:
- Syntax of configuration files
- Service configuration validity
- Kernel parameter compatibility

---

## system.sh - System Configuration

### Core System Functions

#### `configure_timezone_and_locale()`
**Purpose**: Configure system timezone and locale settings  
**Actions**:
- Set timezone (default: UTC, configurable via `$TIMEZONE`)
- Configure UTF-8 locale
- Generate required locales

#### `setup_ntp_synchronization()`
**Purpose**: Configure NTP time synchronization  
**Actions**:
- Enable systemd-timesyncd
- Configure reliable NTP servers
- Ensure time synchronization

#### `configure_persistent_logging()`
**Purpose**: Configure persistent systemd journal logging  
**Actions**:
- Create journal storage directory
- Configure journal size limits
- Enable persistent storage

#### `configure_hostname()`
**Purpose**: Configure system hostname and FQDN  
**Parameters**: Uses `$HOSTNAME` and `$DOMAIN` variables  
**Actions**:
- Set system hostname
- Update `/etc/hosts` with FQDN
- Configure hostname resolution

### Kernel and System Parameters

#### `configure_kernel_parameters()`
**Purpose**: Apply kernel security and performance parameters  
**Configuration Files**:
- `10-base.conf` - Base system parameters
- `20-security-minimal.conf` - Minimal security parameters
- `21-security-standard.conf` - Standard security parameters
- `22-security-hardened.conf` - Hardened security parameters
- `70-vm.conf` - Virtual machine optimizations
- `71-baremetal.conf` - Bare metal optimizations

#### `configure_system_limits()`
**Purpose**: Configure system resource limits and security restrictions  
**Actions**:
- Apply limits from `config/security/limits/`
- Configure process limits
- Set security restrictions

### Package Management

#### `configure_apt_production()`
**Purpose**: Configure APT for production use  
**Actions**:
- Apply production APT configuration
- Configure unattended upgrades
- Set up security repositories

#### `remove_unnecessary_packages()`
**Purpose**: Remove development and unnecessary packages  
**Removes**:
- Development packages (build-essential, compilers)
- Documentation packages
- Packages listed in `packages-remove.conf`

### Status and Testing

#### `test_system_configs()`
**Purpose**: Test all system configurations for validity  
**Tests**:
- Service configuration syntax
- Kernel parameter validity
- Package manager configuration

#### `show_system_status()`
**Purpose**: Display comprehensive system status information  
**Displays**:
- System information (OS, kernel, uptime)
- Service statuses
- Security configuration status
- Package update information

---

## ssh-server.sh - SSH Server Configuration

### Key Management

#### `generate_host_keys()`
**Purpose**: Generate secure ED25519 SSH host keys  
**Actions**:
- Backup existing keys
- Remove weak key types (RSA, DSA, ECDSA)
- Generate new ED25519 keys with secure parameters

### Server Configuration

#### `configure_ssh_server()`
**Purpose**: Configure SSH server with modern security settings  
**Configuration**:
- ED25519-only cryptography
- Disable password authentication
- Configure secure algorithms
- Apply security restrictions

**Template Files**:
- `01-security.conf` - Core security settings
- `02-sftp.conf` - SFTP subsystem configuration
- `sshd-aggressive.conf` - Maximum security variant

#### `setup_sftp_users()`
**Purpose**: Configure SFTP-only user restrictions (optional)  
**Configuration**:
- Chroot SFTP users
- Restrict SFTP-only access
- Secure file transfer setup

### Testing and Validation

#### `test_ssh_config()`
**Purpose**: Test SSH configuration before applying  
**Tests**:
- SSH daemon configuration syntax
- Key file permissions and validity
- Service restart capability

#### `show_ssh_status()`
**Purpose**: Display SSH server status and configuration  
**Displays**:
- SSH service status
- Active connections
- Configuration summary
- Security settings

### Recovery Functions

#### `rollback_ssh_config()`
**Purpose**: Rollback SSH configuration to backup  
**Actions**:
- Restore original configuration
- Restart SSH service
- Verify service functionality

#### `configure_ssh_server_complete()`
**Purpose**: Complete SSH server configuration orchestration  
**Orchestrates**:
- Key generation
- Configuration application
- Service restart
- Validation testing

---

## ssh-client.sh - SSH Client Configuration

### Client Configuration

#### `setup_ssh_client()`
**Purpose**: Configure SSH client with optimized settings  
**Configuration**:
- ControlMaster connection multiplexing
- Connection persistence
- Modern cryptography preferences
- Performance optimizations

#### `create_ssh_connections_script()`
**Purpose**: Create SSH connection management utility  
**Creates**: `/usr/local/bin/ssh-connections.sh`  
**Features**:
- List active SSH connections
- Connection monitoring
- Session management

### Tools and Utilities

#### `setup_ssh_tools()`
**Purpose**: Install SSH management and monitoring tools  
**Tools**:
- SSH connection monitor
- SSH audit utilities
- Performance monitoring scripts

### Status and Testing

#### `show_ssh_client_status()`
**Purpose**: Display SSH client configuration status  
**Displays**:
- Client configuration summary
- Available tools
- Connection multiplexing status

#### `test_ssh_client_config()`
**Purpose**: Test SSH client configuration  
**Tests**:
- Configuration file syntax
- Client connectivity
- Multiplexing functionality

---

## admin-user.sh - Admin User Management

### User Creation

#### `prompt_admin_username()`
**Purpose**: Prompt for admin username if not provided  
**Returns**: Sets `$ADMIN_USER` global variable

#### `create_admin_user()`
**Purpose**: Create admin user with secure defaults  
**Actions**:
- Create user account
- Set secure home directory permissions
- Configure user shell and environment

### Password and Authentication

#### `configure_admin_password()`
**Purpose**: Configure admin user password securely  
**Actions**:
- Prompt for secure password
- Set password with proper hashing
- Configure password policies

#### `setup_admin_ssh_directory()`
**Purpose**: Set up SSH directory and authorized keys  
**Actions**:
- Create `.ssh` directory with secure permissions
- Set up `authorized_keys` file
- Configure SSH key authentication

#### `install_admin_public_key()`
**Purpose**: Install admin public key from config directory  
**Source**: `config/ssh/keys/admin.pub.example`  
**Actions**:
- Copy public key to authorized_keys
- Set proper permissions
- Validate key format

#### `generate_admin_ssh_keys()`
**Purpose**: Generate new SSH key pair for admin user  
**Actions**:
- Generate ED25519 key pair
- Secure private key permissions
- Display public key for external use

### System Integration

#### `configure_admin_groups()`
**Purpose**: Add admin user to necessary system groups  
**Groups**:
- `sudo` - Privilege escalation
- `ssh` - SSH access (if group exists)
- Additional groups based on system requirements

#### `configure_admin_sudo()`
**Purpose**: Configure sudo access for admin user  
**Configuration**:
- Passworded sudo access
- Useful read-only operations without password
- Security logging

#### `configure_admin_environment()`
**Purpose**: Set up admin user bash environment  
**Configuration**:
- Useful aliases for system administration
- Security shortcuts
- System monitoring commands
- Log viewing utilities

### Testing and Status

#### `test_admin_user_config()`
**Purpose**: Test admin user configuration  
**Tests**:
- User account validity
- SSH access configuration
- Sudo permissions
- Environment setup

#### `show_admin_user_status()`
**Purpose**: Display admin user status and configuration  
**Displays**:
- User account information
- Group memberships
- SSH key status
- Sudo configuration

### Complete Setup

#### `setup_admin_user_complete()`
**Purpose**: Complete admin user setup orchestration  
**Orchestrates**:
- User creation
- SSH configuration
- System integration
- Environment setup
- Testing and validation

---

## Configuration Template Variables

### SSH Configuration Variables
- `${SSH_PORT}` - SSH port number (default: 22)
- `${MODERN_KEXALGORITHMS}` - Key exchange algorithms
- `${MODERN_CIPHERS}` - Encryption ciphers
- `${MODERN_MACS}` - Message authentication codes
- `${MODERN_HOSTKEY_ALGORITHMS}` - Host key algorithms
- `${MODERN_PUBKEY_ALGORITHMS}` - Public key algorithms
- `${ALLOW_AGENT_FORWARDING}` - Agent forwarding setting
- `${ALLOW_TCP_FORWARDING}` - TCP forwarding setting

### System Configuration Variables
- `${TIMEZONE}` - System timezone (default: UTC)
- `${HOSTNAME}` - System hostname
- `${DOMAIN}` - Domain name for FQDN
- `${ADMIN_USER}` - Admin username

### Security Profile Variables
- `${SECURITY_PROFILE}` - Security profile (minimal/standard/hardened)
- `${DRY_RUN}` - Dry run mode flag (true/false)

---

## Error Handling and Return Codes

### Standard Return Codes
- `0` - Success
- `1` - General error
- `2` - Invalid argument
- `3` - Permission denied
- `4` - Required dependency missing
- `5` - Configuration validation failed

### Error Handling Pattern
All functions implement consistent error handling:
```bash
function_name() {
    # Validation
    if [[ condition ]]; then
        error "Error message"
        return 1
    fi
    
    # Main logic with error checking
    if ! command; then
        error "Command failed"
        return 1
    fi
    
    # Success
    return 0
}
```

### Cleanup and Rollback
- All functions support dry-run mode via `$DRY_RUN` variable
- Critical operations create automatic backups
- Rollback functions available for major configuration changes
- Cleanup functions registered for signal handling

---

## Security Considerations

### Input Validation
- All user inputs validated before use
- Path traversal protection
- Command injection prevention
- File permission verification

### Privilege Management
- Functions require appropriate privileges
- Temporary privilege escalation where needed
- Secure file permissions applied
- User creation with minimal privileges

### Cryptographic Standards
- ED25519 keys exclusively
- Post-quantum ready algorithms
- Secure random number generation
- Modern cipher suites only

### Audit and Logging
- All operations logged with timestamps
- Security events logged to system journal
- Configuration changes tracked
- Rollback capability for all changes