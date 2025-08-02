# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains a unified Linux server hardening and SSH infrastructure script designed for Debian/Ubuntu systems. The project combines SSH security configuration and system hardening into a single, comprehensive solution with modular architecture and multiple security profiles.

## Core Architecture

### Main Script
- **`server-setup.sh`** - Main unified script orchestrating all configuration
- Combines SSH and system hardening functionality
- Supports multiple modes: `system`, `ssh`, `both`
- Three security profiles: `minimal`, `standard`, `hardened`

### Library Structure (`lib/`)
The codebase follows a modular library pattern with domain-specific functionality:

- **`common.sh`** - Core utilities (logging, validation, backup, error handling)
- **`security.sh`** - Security hardening orchestration across SSH and system
- **`system.sh`** - System configuration (timezone, packages, services)
- **`ssh-server.sh`** - SSH daemon configuration and key management
- **`ssh-client.sh`** - SSH client configuration and optimization
- **`admin-user.sh`** - Administrative user creation and configuration

### Configuration Hierarchy (`config/`)
External configurations organized by functional domain:

```
config/
├── system/           # Core system configurations
│   ├── sysctl/      # Kernel parameters by security profile
│   ├── systemd/     # Service configurations
│   ├── network/     # Network settings
│   └── udev/        # Device rules
├── security/        # Security hardening
│   ├── apparmor/    # AppArmor profiles
│   ├── fail2ban/    # Intrusion prevention
│   ├── firewall/    # iptables rules
│   ├── hardening/   # General security measures
│   ├── limits/      # Resource constraints
│   └── sudoers/     # Privilege escalation
├── ssh/             # SSH-specific configurations
│   ├── server/      # sshd configuration templates
│   ├── client/      # SSH client optimization
│   ├── keys/        # Public key examples
│   └── services/    # Related services (autossh)
├── applications/    # Application configurations
│   ├── apt/         # Package management
│   └── logging/     # Log rotation
└── scripts/         # Management and monitoring tools
    ├── ssh/         # SSH connection management
    ├── security/    # Security audit tools
    ├── monitoring/  # System monitoring scripts
    └── management/  # Administrative utilities
```

## Common Development Commands

### Running the Script
```bash
# Full server setup with default (standard) security
sudo ./server-setup.sh

# SSH hardening only with custom port
sudo ./server-setup.sh -m ssh -p 2222

# Maximum security hardening
sudo ./server-setup.sh -s hardened

# System hardening only (no SSH changes)
sudo ./server-setup.sh -m system

# Dry run to preview changes
sudo ./server-setup.sh -d

# Create admin user during setup
sudo ./server-setup.sh -u admin
```

### Development and Testing
```bash
# Syntax checking
shellcheck *.sh lib/*.sh config/scripts/**/*.sh

# Test individual library functions
bash -c "source lib/common.sh && log_info 'Test message'"

# Validate configuration file syntax
# SSH configs: sshd -t -f config/ssh/server/01-security.conf
# sysctl: sysctl -p config/system/sysctl/21-security-standard.conf

# Check generated backup/restore functionality
ls -la /root/server-backup-*/
```

### Security Profile Testing
```bash
# Test different security profiles in dry-run mode
sudo ./server-setup.sh -s minimal -d
sudo ./server-setup.sh -s standard -d  
sudo ./server-setup.sh -s hardened -d

# Test specific modes
sudo ./server-setup.sh -m ssh -d
sudo ./server-setup.sh -m system -d
```

## Key Patterns and Conventions

### Modular Shell Framework
All scripts follow consistent patterns:
- **Strict error handling**: `set -euo pipefail` in all scripts
- **Sourcing pattern**: Libraries source `common.sh` for shared utilities
- **Function naming**: Domain prefixes (e.g., `configure_*`, `apply_*`, `install_*`)
- **Constants**: Readonly variables in SCREAMING_SNAKE_CASE
- **Configuration**: External files in `config/` with variable substitution

### Security-First Approach
- **ED25519-only SSH**: Modern cryptography, no legacy algorithm support
- **Progressive hardening**: Layered security profiles building on each other
- **Fail2ban integration**: Automatic intrusion prevention
- **AppArmor enforcement**: Application confinement in hardened mode
- **Kernel hardening**: sysctl parameters organized by security level

### Error Handling and Safety
- **Automatic backups**: All original configs backed up to `/root/server-backup-TIMESTAMP/`
- **Rollback capability**: Generated restore scripts for emergency recovery
- **Dry-run mode**: `-d` flag previews all changes without applying
- **SSH safety**: Prevents SSH lockout during remote configuration
- **Service validation**: Configuration testing before service restart

### Configuration Management
- **Template system**: Variable substitution in configuration files
- **Profile-based loading**: Different configs per security profile
- **Hierarchical organization**: Logical grouping by functional domain
- **Version compatibility**: Support for Debian 10+ and Ubuntu 18.04+

## Security Profiles Architecture

### Minimal Profile
- Basic kernel security parameters (`20-security-minimal.conf`)
- Core dump disabling
- Basic fail2ban SSH protection
- Essential hardening only

### Standard Profile (Default)  
- Enhanced kernel security (`21-security-standard.conf`)
- Network security hardening
- Process accounting and auditing
- Unattended security updates
- Balanced security without operational complexity

### Hardened Profile
- Maximum security parameters (`22-security-hardened.conf`)
- AppArmor enforcement with custom profiles
- Advanced fail2ban configuration
- Protocol blacklisting and secure mount options
- Strict resource limits and access controls

## SSH Configuration System

### Modern Cryptography Standards
- **Host Keys**: ED25519 only (`ssh_host_ed25519_key`)
- **Key Exchange**: Post-quantum ready algorithms (`sntrup761x25519-sha512@openssh.com`)
- **Ciphers**: ChaCha20-Poly1305 and AES256-GCM
- **MACs**: HMAC-SHA2 with ETM (Encrypt-Then-MAC)
- **Public Key**: ED25519 authentication only

### Configuration Templates
- **`01-security.conf`** - Core security settings with variable substitution
- **`02-sftp.conf`** - SFTP subsystem configuration
- **`sshd-aggressive.conf`** - Maximum security variant
- **`ssh-client.conf`** - Client-side optimization (ControlMaster, multiplexing)

## Development Guidelines

### Adding New Configurations
1. Place configuration files in appropriate `config/` subdirectory
2. Use variable substitution for dynamic values (e.g., `${SSH_PORT}`)
3. Document configuration purpose and security impact
4. Test with dry-run mode before implementation

### Extending Security Profiles
1. Add new sysctl parameters to appropriate profile file
2. Update `security.sh` functions for new hardening measures
3. Ensure progressive layering (hardened includes standard includes minimal)
4. Test compatibility across supported OS versions

### Library Function Development
1. Follow existing naming conventions with domain prefixes
2. Implement comprehensive input validation
3. Support dry-run mode with conditional execution
4. Include detailed logging for all operations
5. Handle errors gracefully with informative messages

### Configuration File Validation
- SSH configurations: Use `sshd -t -f <config-file>` for syntax validation
- sysctl parameters: Test with `sysctl -p <config-file>`
- Service files: Validate with `systemd-analyze verify <service-file>`
- Shell scripts: Always run `shellcheck` before committing

## Backup and Recovery System

### Automatic Backup Creation
- Backup directory: `/root/server-backup-TIMESTAMP/`
- Includes all original configuration files
- Generates automatic restore script
- Preserves file permissions and ownership

### Recovery Process
```bash
# Restore from backup
cd /root/server-backup-TIMESTAMP/
sudo ./restore.sh

# Manual file restoration
sudo cp backup/sshd_config /etc/ssh/sshd_config
sudo systemctl restart ssh
```

## Management Scripts

### Post-Installation Tools
- **`ssh-audit.sh`** - SSH security configuration audit
- **`ssh-connections.sh`** - Active SSH connection monitoring  
- **`apparmor-monitor.sh`** - AppArmor profile monitoring
- **`apparmor-report.sh`** - Security policy compliance reporting

### Administrative Utilities
- **`apparmor-mgmt.sh`** - AppArmor profile management
- **`deploy-service-profile.sh`** - Service-specific security profile deployment

All management scripts are installed to `/usr/local/bin/` and made executable during setup.