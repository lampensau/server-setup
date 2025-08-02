# Project Structure Index

## Overview

This document provides a comprehensive index of the Unified Server Setup Framework project structure, organized by functional areas and relationships between components.

## Repository Structure

```
server-setup/
├── 📄 server-setup.sh              # Main unified orchestration script
├── 📄 README.md                    # User documentation and quick start
├── 📄 CLAUDE.md                    # Development guidance for Claude Code
│
├── 📁 lib/                         # Core library modules
│   ├── 📄 common.sh                # Shared utilities and core functions
│   ├── 📄 security.sh              # Security hardening orchestration
│   ├── 📄 system.sh                # System configuration functions
│   ├── 📄 ssh-server.sh            # SSH daemon configuration
│   ├── 📄 ssh-client.sh            # SSH client optimization
│   └── 📄 admin-user.sh            # Administrative user management
│
├── 📁 config/                      # External configuration files
│   ├── 📁 system/                  # Core system configurations
│   │   ├── 📁 sysctl/              # Kernel parameters by security profile
│   │   │   ├── 📄 10-base.conf             # Base system parameters
│   │   │   ├── 📄 20-security-minimal.conf # Minimal security hardening
│   │   │   ├── 📄 21-security-standard.conf# Standard security profile
│   │   │   ├── 📄 22-security-hardened.conf# Hardened security profile
│   │   │   ├── 📄 70-vm.conf               # Virtual machine optimizations
│   │   │   ├── 📄 71-baremetal.conf        # Bare metal optimizations
│   │   │   └── 📄 80-ipv6-disable.conf     # IPv6 disabling parameters
│   │   ├── 📁 systemd/             # Systemd service configurations
│   │   │   ├── 📄 journald.conf            # Journal logging configuration
│   │   │   ├── 📄 resolved.conf            # DNS resolution configuration
│   │   │   ├── 📄 timesyncd.conf           # NTP synchronization setup
│   │   │   ├── 📄 systemd-timeout.conf     # Service timeout configuration
│   │   │   └── 📄 systemd-coredump-disable.conf # Core dump disabling
│   │   ├── 📁 network/             # Network configurations
│   │   │   └── 📄 hosts.template           # Hostname resolution template
│   │   └── 📁 udev/                # Device rules
│   │       └── 📄 60-io-scheduler.rules    # I/O scheduler optimization
│   │
│   ├── 📁 security/                # Security hardening configurations
│   │   ├── 📁 apparmor/            # AppArmor mandatory access control
│   │   │   ├── 📄 grub.cfg                 # GRUB security configuration
│   │   │   └── 📄 tunables-site-specific.conf # Site-specific tunables
│   │   ├── 📁 fail2ban/            # Intrusion prevention system
│   │   │   ├── 📄 jail.local              # Main jail configuration
│   │   │   ├── 📄 ssh.conf                # SSH-specific jail settings
│   │   │   └── 📁 jail.d/                 # Additional jail definitions
│   │   │       └── 📄 ssh-basic.conf      # Basic SSH protection
│   │   ├── 📁 firewall/            # Firewall rule sets
│   │   │   ├── 📄 iptables.rules          # IPv4 firewall rules
│   │   │   └── 📄 ip6tables.rules         # IPv6 firewall rules
│   │   ├── 📁 hardening/           # General security hardening
│   │   │   ├── 📄 99-hardening.conf       # Comprehensive hardening settings
│   │   │   ├── 📄 blacklist-protocols.conf# Protocol blacklisting
│   │   │   └── 📄 fstab-secure-mounts.conf# Secure filesystem mount options
│   │   ├── 📁 limits/              # System resource limits
│   │   │   └── 📄 limits-disable-core.conf# Core dump restrictions
│   │   └── 📁 sudoers/             # Privilege escalation configuration
│   │       └── 📄 logging.conf            # Sudo logging configuration
│   │
│   ├── 📁 ssh/                     # SSH-specific configurations
│   │   ├── 📁 server/              # SSH daemon configurations
│   │   │   ├── 📄 01-security.conf         # Core SSH security settings
│   │   │   ├── 📄 02-sftp.conf            # SFTP subsystem configuration
│   │   │   └── 📄 sshd-aggressive.conf    # Maximum security SSH config
│   │   ├── 📁 client/              # SSH client configurations
│   │   │   └── 📄 ssh-client.conf         # Client optimization settings
│   │   ├── 📁 keys/                # SSH key examples and templates
│   │   │   └── 📄 admin.pub.example       # Example admin public key
│   │   └── 📁 services/            # SSH-related services
│   │       └── 📄 autossh@.service        # AutoSSH service template
│   │
│   ├── 📁 applications/            # Application-specific configurations
│   │   ├── 📁 apt/                 # Package management
│   │   │   ├── 📄 apt-production.conf     # Production APT configuration
│   │   │   └── 📄 unattended-upgrades.conf# Automatic security updates
│   │   └── 📁 logging/             # Logging configurations
│   │       ├── 📄 logrotate-apps.conf     # Application log rotation
│   │       └── 📄 rsyslog-separation.conf # Log separation configuration
│   │
│   └── 📁 scripts/                 # Management and monitoring scripts
│       ├── 📁 ssh/                 # SSH management tools
│       │   └── 📄 ssh-connections.sh      # SSH connection monitoring
│       ├── 📁 security/            # Security audit tools
│       │   └── 📄 ssh-audit.sh            # SSH security audit script
│       ├── 📁 monitoring/          # System monitoring scripts
│       │   ├── 📄 apparmor-monitor.sh     # AppArmor profile monitoring
│       │   └── 📄 apparmor-report.sh      # Security compliance reporting
│       └── 📁 management/          # Administrative utilities
│           ├── 📄 apparmor-mgmt.sh        # AppArmor profile management
│           └── 📄 deploy-service-profile.sh # Service profile deployment
│
├── 📁 templates/                   # Template files for dynamic generation
│   ├── 📁 ssh/                     # SSH configuration templates
│   └── 📁 system/                  # System configuration templates
│       └── 📄 restore.sh.template         # Backup restoration template
│
└── 📁 docs/                        # Project documentation (generated)
    ├── 📄 API.md                   # Function API documentation
    ├── 📄 STRUCTURE.md             # This structure index
    └── 📄 NAVIGATION.md            # Cross-reference navigation guide
```

## Functional Component Mapping

### Core Execution Flow
```
server-setup.sh
├── Sources: lib/common.sh (core utilities)
├── Orchestrates: All lib/*.sh modules based on mode selection
├── Uses: config/* configurations based on security profile
└── Generates: Backup and restore scripts in templates/
```

### Library Dependency Graph
```
common.sh (base utilities)
├── Used by: ALL other libraries
├── Provides: Logging, validation, backup, template processing
└── Dependencies: None (pure shell functions)

security.sh
├── Sources: common.sh
├── Uses: config/security/* configurations
├── Orchestrates: System and SSH security hardening
└── Integrates: fail2ban, AppArmor, firewall, kernel parameters

system.sh
├── Sources: common.sh
├── Uses: config/system/* configurations
├── Functions: System configuration, package management
└── Integrates: systemd, sysctl, APT, locale

ssh-server.sh
├── Sources: common.sh
├── Uses: config/ssh/server/* configurations
├── Functions: SSH daemon configuration, key management
└── Integrates: OpenSSH, fail2ban SSH jails

ssh-client.sh
├── Sources: common.sh
├── Uses: config/ssh/client/* configurations
├── Functions: SSH client optimization
└── Integrates: SSH client multiplexing, tools

admin-user.sh
├── Sources: common.sh
├── Uses: config/ssh/keys/* for key installation
├── Functions: Administrative user creation and configuration
└── Integrates: User management, SSH keys, sudo, environment
```

### Configuration Hierarchy

#### Security Profile Layering
```
Security Profiles (cumulative application):
├── Minimal (base security)
│   ├── sysctl/20-security-minimal.conf
│   ├── Basic fail2ban configuration
│   └── Core dump disabling
├── Standard (builds on minimal)
│   ├── sysctl/21-security-standard.conf
│   ├── Enhanced fail2ban rules
│   ├── Basic firewall configuration
│   └── Process accounting
└── Hardened (builds on standard)
    ├── sysctl/22-security-hardened.conf
    ├── Advanced fail2ban configuration
    ├── AppArmor enforcement
    ├── Protocol blacklisting
    └── Secure mount options
```

#### Configuration Loading Order
```
1. Base Configuration
   ├── sysctl/10-base.conf (always applied)
   ├── systemd/* configurations
   └── network/hosts.template

2. Security Profile Configuration
   ├── sysctl/2X-security-[profile].conf
   ├── security/* based on profile level
   └── fail2ban configurations

3. Mode-Specific Configuration
   ├── SSH Mode: ssh/* configurations
   ├── System Mode: Additional system configurations
   └── Both Mode: All configurations

4. Environment-Specific Optimization
   ├── Virtual Machine: sysctl/70-vm.conf
   ├── Bare Metal: sysctl/71-baremetal.conf
   └── IPv6 Disable: sysctl/80-ipv6-disable.conf (if requested)
```

### Script Installation Locations

#### System Integration Points
```
/etc/ssh/
├── sshd_config.d/ (SSH server configurations)
├── ssh_config.d/ (SSH client configurations)
└── ssh_host_ed25519_key* (Generated host keys)

/etc/sysctl.d/
├── 10-base.conf
├── 2X-security-*.conf (based on profile)
├── 7X-optimization.conf (based on environment)
└── 80-ipv6-disable.conf (optional)

/etc/systemd/
├── journald.conf.d/
├── resolved.conf.d/
├── timesyncd.conf.d/
└── system.conf.d/

/etc/fail2ban/
├── jail.local
├── jail.d/ssh-*.conf
└── filter.d/ (custom filters)

/etc/security/
├── limits.d/
└── Other security configurations

/usr/local/bin/ (Management scripts)
├── ssh-audit.sh
├── ssh-connections.sh
├── apparmor-monitor.sh
├── apparmor-report.sh
├── apparmor-mgmt.sh
└── deploy-service-profile.sh
```

## File Type Classification

### Executable Scripts (13 files)
```
Main Script:
└── server-setup.sh (Main orchestration)

Library Modules (6 files):
├── lib/common.sh
├── lib/security.sh
├── lib/system.sh
├── lib/ssh-server.sh
├── lib/ssh-client.sh
└── lib/admin-user.sh

Management Scripts (6 files):
├── config/scripts/ssh/ssh-connections.sh
├── config/scripts/security/ssh-audit.sh
├── config/scripts/monitoring/apparmor-monitor.sh
├── config/scripts/monitoring/apparmor-report.sh
├── config/scripts/management/apparmor-mgmt.sh
└── config/scripts/management/deploy-service-profile.sh
```

### Configuration Files (31 files)
```
System Configuration (9 files):
├── config/system/sysctl/* (7 files)
├── config/system/systemd/* (5 files)
├── config/system/network/* (1 file)
└── config/system/udev/* (1 file)

Security Configuration (15 files):
├── config/security/apparmor/* (2 files)
├── config/security/fail2ban/* (3 files)
├── config/security/firewall/* (2 files)
├── config/security/hardening/* (3 files)
├── config/security/limits/* (1 file)
└── config/security/sudoers/* (1 file)

SSH Configuration (5 files):
├── config/ssh/server/* (3 files)
├── config/ssh/client/* (1 file)
├── config/ssh/keys/* (1 file)
└── config/ssh/services/* (1 file)

Application Configuration (4 files):
├── config/applications/apt/* (2 files)
└── config/applications/logging/* (2 files)
```

### Template Files (2 files)
```
├── config/system/network/hosts.template
└── templates/system/restore.sh.template
```

### Documentation Files (4 files)
```
├── README.md (User documentation)
├── CLAUDE.md (Development guidance)
├── docs/API.md (Function documentation)
└── docs/STRUCTURE.md (This file)
```

## Component Relationships

### Data Flow Architecture
```
User Input → server-setup.sh → Validation (common.sh) → Mode Selection
                             ↓
Mode Selection → Library Loading → Configuration Processing → Template Substitution
                             ↓
Template Substitution → Backup Creation → Configuration Application → Service Management
                             ↓
Service Management → Validation Testing → Status Display → Completion
```

### Configuration Dependencies
```
SSH Server Configuration:
├── Depends on: system/sysctl security parameters
├── Requires: OpenSSH package availability
├── Integrates with: fail2ban SSH jails
└── Uses: SSH key generation from ssh-server.sh

System Configuration:
├── Depends on: Base system packages
├── Integrates with: systemd service management
├── Requires: Kernel parameter support
└── Uses: Package management configuration

Security Configuration:
├── Orchestrates: Both SSH and system security
├── Depends on: Available security tools
├── Integrates: fail2ban, AppArmor, firewall
└── Uses: Security profile-specific configurations

Admin User Configuration:
├── Depends on: System user management
├── Integrates with: SSH key management
├── Uses: Sudo configuration templates
└── Requires: SSH server configuration (for key setup)
```

### Backup and Recovery Architecture
```
Backup Creation (common.sh):
├── Creates: /root/server-backup-TIMESTAMP/
├── Preserves: Original configuration files
├── Generates: Automatic restore script
└── Maintains: File permissions and ownership

Backup Structure:
/root/server-backup-TIMESTAMP/
├── backup/ (Original files with directory structure preserved)
├── restore.sh (Generated restoration script)
├── backup.log (Backup operation log)
└── config.env (Environment variables at backup time)

Restoration Process:
├── Validates: Backup integrity
├── Stops: Affected services
├── Restores: Original configurations
├── Restarts: Services in proper order
└── Validates: Service functionality
```

### Error Handling Flow
```
Error Detection → Logging (common.sh) → Cleanup Assessment → Rollback Decision
                                      ↓
Rollback Decision → Service Stop → Configuration Restore → Service Restart → Validation
                                      ↓
Validation → Success Confirmation → Status Report → Exit
           ↓
           Failure Report → Manual Intervention Required
```

## Integration Points

### Operating System Integration
```
Systemd Integration:
├── Service configuration through systemd conf.d directories
├── Journal logging configuration
├── Service dependency management
└── Timer-based scheduling for maintenance

Package Management Integration:
├── APT configuration for security updates
├── Package removal for hardening
├── Repository configuration
└── Unattended upgrade configuration

Kernel Integration:
├── sysctl parameter configuration
├── Module loading and blacklisting
├── Security parameter enforcement
└── Performance optimization parameters
```

### Security Framework Integration
```
AppArmor Integration:
├── Profile deployment and management
├── Enforcement mode configuration
├── Application confinement
└── Security policy compliance

Fail2ban Integration:
├── SSH protection configuration
├── Multi-service jail management
├── Ban policy configuration
└── Recidive protection

Firewall Integration:
├── iptables rule deployment
├── Service-specific access control
├── Protocol restriction implementation
└── Connection state management
```

### SSH Infrastructure Integration
```
OpenSSH Integration:
├── Modern cryptography enforcement
├── Key management automation
├── Client optimization configuration
└── Security audit capability

Key Management Integration:
├── ED25519 key generation
├── Legacy key removal
├── Public key deployment
└── Key rotation preparation

Connection Management Integration:
├── Multiplexing configuration
├── Connection monitoring
├── Performance optimization
└── Security audit trails
```

This structure index provides a comprehensive view of how all components work together to create a unified, secure server configuration framework.