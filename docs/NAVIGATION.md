# Navigation and Cross-Reference Guide

## Documentation Index

This guide provides navigation paths and cross-references for the Unified Server Setup Framework documentation and codebase.

### Quick Navigation

| Document | Purpose | Best Used For |
|----------|---------|---------------|
| [README.md](../README.md) | User guide and quick start | First-time users, command reference |
| [CLAUDE.md](../CLAUDE.md) | Development guidance | Claude Code development assistance |
| [API.md](API.md) | Function documentation | Function usage, parameters, return codes |
| [STRUCTURE.md](STRUCTURE.md) | Project structure index | Understanding project organization |
| **NAVIGATION.md** | This file | Finding information quickly |

---

## Quick Reference Sections

### 🚀 Getting Started
**For new users starting with the framework:**

1. **[README.md → Quick Start](../README.md#quick-start)** - Basic usage examples
2. **[README.md → Command Reference](../README.md#command-reference)** - All available options
3. **[README.md → Examples](../README.md#examples)** - Common usage scenarios
4. **[CLAUDE.md → Common Development Commands](../CLAUDE.md#common-development-commands)** - Development workflow

### 🛠️ Development
**For developers working on the framework:**

1. **[CLAUDE.md → Key Patterns and Conventions](../CLAUDE.md#key-patterns-and-conventions)** - Coding standards
2. **[API.md → Library Structure](API.md#library-structure)** - Function organization
3. **[STRUCTURE.md → Component Relationships](STRUCTURE.md#component-relationships)** - Architecture understanding
4. **[CLAUDE.md → Development Guidelines](../CLAUDE.md#development-guidelines)** - Best practices

### 🔒 Security Configuration
**For understanding and customizing security settings:**

1. **[README.md → Security Profiles](../README.md#security-profiles)** - Profile overview
2. **[CLAUDE.md → Security Profiles Architecture](../CLAUDE.md#security-profiles-architecture)** - Detailed implementation
3. **[STRUCTURE.md → Security Profile Layering](STRUCTURE.md#configuration-hierarchy)** - Configuration hierarchy
4. **[API.md → security.sh](API.md#securitysh---security-hardening)** - Security function reference

### 🔧 Configuration Management
**For working with configuration files:**

1. **[STRUCTURE.md → Configuration Hierarchy](STRUCTURE.md#configuration-hierarchy)** - File organization
2. **[API.md → Configuration Template Variables](API.md#configuration-template-variables)** - Variable reference
3. **[CLAUDE.md → Configuration Management](../CLAUDE.md#key-patterns-and-conventions)** - Usage patterns
4. **[STRUCTURE.md → System Integration Points](STRUCTURE.md#integration-points)** - Where configs are applied

---

## Function Reference Cross-Index

### By Use Case

#### Initial Setup and Validation
```
check_dependencies() → API.md#check_dependencies
validate_inputs() → API.md#validate_inputs
safety_check() → API.md#safety_check
detect_os() → API.md#detect_os
```

#### Backup and Recovery
```
create_backup() → API.md#create_backup
rollback_config() → API.md#rollback_config
execute_with_rollback() → API.md#execute_with_rollback
```

#### SSH Server Configuration
```
generate_host_keys() → API.md#generate_host_keys
configure_ssh_server() → API.md#configure_ssh_server
test_ssh_config() → API.md#test_ssh_config
show_ssh_status() → API.md#show_ssh_status
```

#### System Hardening
```
apply_security_hardening() → API.md#apply_security_hardening
configure_kernel_parameters() → API.md#configure_kernel_parameters
configure_basic_fail2ban() → API.md#configure_basic_fail2ban
apply_secure_mount_options() → API.md#apply_secure_mount_options
```

#### User Management
```
create_admin_user() → API.md#create_admin_user
configure_admin_password() → API.md#configure_admin_password
setup_admin_ssh_directory() → API.md#setup_admin_ssh_directory
configure_admin_sudo() → API.md#configure_admin_sudo
```

### By Library Module

#### common.sh Functions
```
Logging: log(), info(), warn(), error(), success()
Validation: validate_inputs(), check_dependencies(), safety_check()
File Operations: atomic_install(), process_config_template()
System Detection: detect_os(), check_openssh_version()
Backup: create_backup(), rollback_config()
```
**Reference**: [API.md → common.sh](API.md#commonsh---core-utilities)

#### security.sh Functions
```
Main: apply_security_hardening()
Profile Functions: apply_minimal_security(), apply_standard_security(), apply_hardened_security()
Specialized: configure_basic_fail2ban(), configure_advanced_fail2ban(), configure_basic_firewall()
```
**Reference**: [API.md → security.sh](API.md#securitysh---security-hardening)

#### system.sh Functions
```
Core System: configure_timezone_and_locale(), setup_ntp_synchronization(), configure_hostname()
Kernel: configure_kernel_parameters(), configure_system_limits()
Packages: configure_apt_production(), remove_unnecessary_packages()
Status: test_system_configs(), show_system_status()
```
**Reference**: [API.md → system.sh](API.md#systemsh---system-configuration)

#### ssh-server.sh Functions
```
Keys: generate_host_keys()
Configuration: configure_ssh_server(), setup_sftp_users()
Testing: test_ssh_config(), show_ssh_status()
Recovery: rollback_ssh_config()
```
**Reference**: [API.md → ssh-server.sh](API.md#ssh-serversh---ssh-server-configuration)

#### ssh-client.sh Functions
```
Setup: setup_ssh_client(), setup_ssh_tools()
Management: create_ssh_connections_script()
Status: show_ssh_client_status(), test_ssh_client_config()
```
**Reference**: [API.md → ssh-client.sh](API.md#ssh-clientsh---ssh-client-configuration)

#### admin-user.sh Functions
```
Creation: create_admin_user(), configure_admin_password()
SSH Setup: setup_admin_ssh_directory(), install_admin_public_key(), generate_admin_ssh_keys()
System Integration: configure_admin_groups(), configure_admin_sudo(), configure_admin_environment()
Testing: test_admin_user_config(), show_admin_user_status()
```
**Reference**: [API.md → admin-user.sh](API.md#admin-usersh---admin-user-management)

---

## Configuration File Cross-Reference

### By Security Profile

#### Minimal Profile Files
```
sysctl/20-security-minimal.conf → Basic kernel security
security/limits/limits-disable-core.conf → Core dump restrictions
security/fail2ban/jail.d/ssh-basic.conf → Basic SSH protection
```

#### Standard Profile Files (includes minimal)
```
sysctl/21-security-standard.conf → Enhanced kernel security
security/fail2ban/jail.local → Standard fail2ban configuration
applications/apt/unattended-upgrades.conf → Automatic security updates
```

#### Hardened Profile Files (includes standard)
```
sysctl/22-security-hardened.conf → Maximum kernel security
security/apparmor/* → Mandatory access control
security/hardening/blacklist-protocols.conf → Protocol restrictions
security/hardening/fstab-secure-mounts.conf → Secure filesystem mounts
```

### By Functional Area

#### SSH Configuration
```
ssh/server/01-security.conf → Core SSH security settings
ssh/server/02-sftp.conf → SFTP subsystem configuration
ssh/server/sshd-aggressive.conf → Maximum security variant
ssh/client/ssh-client.conf → Client optimization
```
**File Details**: [STRUCTURE.md → SSH Configuration](STRUCTURE.md#ssh-configuration-5-files)

#### System Configuration
```
system/sysctl/10-base.conf → Base system parameters
system/systemd/journald.conf → Logging configuration
system/systemd/timesyncd.conf → Time synchronization
system/network/hosts.template → Hostname resolution
```
**File Details**: [STRUCTURE.md → System Configuration](STRUCTURE.md#system-configuration-9-files)

#### Security Configuration
```
security/fail2ban/jail.local → Intrusion prevention
security/firewall/iptables.rules → Network filtering
security/sudoers/logging.conf → Privilege escalation
```
**File Details**: [STRUCTURE.md → Security Configuration](STRUCTURE.md#security-configuration-15-files)

---

## Troubleshooting Cross-Reference

### Common Issues and Solutions

#### SSH Connection Problems
1. **Issue**: Cannot connect after SSH hardening
   - **Check**: [README.md → Verification](../README.md#verification)
   - **Debug**: Use `config/scripts/security/ssh-audit.sh`
   - **Recovery**: [API.md → rollback_ssh_config](API.md#rollback_ssh_config)

#### Service Startup Failures
1. **Issue**: Services fail to start after configuration
   - **Check**: [API.md → test_system_configs](API.md#test_system_configs)
   - **Debug**: [API.md → show_system_status](API.md#show_system_status)
   - **Recovery**: [API.md → rollback_config](API.md#rollback_config)

#### Permission Errors
1. **Issue**: Permission denied errors during setup
   - **Check**: [API.md → check_root](API.md#check_root)
   - **Validate**: [API.md → safety_check](API.md#safety_check)
   - **Fix**: Run with proper sudo privileges

#### Configuration Validation Failures
1. **Issue**: Configuration files fail validation
   - **Check**: [CLAUDE.md → Configuration File Validation](../CLAUDE.md#configuration-file-validation)
   - **Debug**: [API.md → validate_security_configs](API.md#validate_security_configs)
   - **Test**: Use dry-run mode: `sudo ./server-setup.sh -d`

### Recovery Procedures

#### Full System Recovery
```
1. Locate backup directory: ls /root/server-backup-*/
2. Run restore script: cd /root/server-backup-TIMESTAMP && sudo ./restore.sh
3. Verify services: systemctl status ssh sshd fail2ban
4. Test connectivity: ssh -p PORT user@server
```

#### Partial Recovery
```
1. Identify failed component from logs: journalctl -xe
2. Restore specific config: cp backup/path/config /etc/path/config
3. Restart affected service: systemctl restart service
4. Validate functionality: service-specific testing
```

---

## Development Workflow Cross-Reference

### Adding New Features

#### New Configuration Files
1. **Create**: Place in appropriate `config/` subdirectory
2. **Reference**: [CLAUDE.md → Adding New Configurations](../CLAUDE.md#adding-new-configurations)
3. **Template**: Use variable substitution from [API.md → Template Variables](API.md#configuration-template-variables)
4. **Test**: Follow [CLAUDE.md → Configuration File Validation](../CLAUDE.md#configuration-file-validation)

#### New Library Functions
1. **Design**: Follow [CLAUDE.md → Library Function Development](../CLAUDE.md#library-function-development)
2. **Implement**: Use patterns from [API.md → Error Handling](API.md#error-handling-and-return-codes)
3. **Document**: Add to [API.md](API.md) following existing patterns
4. **Test**: Include dry-run support and error handling

#### New Security Profiles
1. **Plan**: Follow [CLAUDE.md → Extending Security Profiles](../CLAUDE.md#extending-security-profiles)
2. **Implement**: Add progressive layering as shown in [STRUCTURE.md](STRUCTURE.md#security-profile-layering)
3. **Test**: Validate with all modes and compatibility matrix
4. **Document**: Update all relevant documentation sections

### Testing Procedures

#### Unit Testing
```
1. Function Testing: Source library and test individual functions
2. Configuration Testing: Use sshd -t, sysctl -p for validation
3. Dry Run Testing: ./server-setup.sh -d with various options
```

#### Integration Testing
```
1. Profile Testing: Test all security profiles in clean environment
2. Mode Testing: Test system, ssh, and both modes
3. Recovery Testing: Test backup and restore functionality
4. Compatibility Testing: Test across supported OS versions
```

#### Validation Testing
```
1. Security Testing: Run security audits post-configuration
2. Service Testing: Verify all services start and function correctly
3. Connection Testing: Verify SSH connectivity and functionality
4. Performance Testing: Verify system performance not degraded
```

---

## External References

### Security Standards and Guidelines
- **SSH Security**: Modern SSH cryptography standards (ED25519, post-quantum ready)
- **Kernel Hardening**: Linux kernel security parameters and best practices
- **System Security**: CIS benchmarks and security frameworks

### Related Tools and Documentation
- **OpenSSH**: Official OpenSSH documentation for configuration options
- **systemd**: systemd service and configuration management
- **fail2ban**: Intrusion prevention system configuration
- **AppArmor**: Mandatory access control system

### Compatibility Information
- **Operating Systems**: [README.md → Compatibility](../README.md#compatibility)
- **Requirements**: [README.md → Requirements](../README.md#requirements)
- **Migration**: [README.md → Migration from Separate Scripts](../README.md#migration-from-separate-scripts)

---

## Search and Discovery

### Finding Functions
1. **By Name**: Use [API.md](API.md) function index
2. **By Purpose**: Use [Function Reference Cross-Index](#function-reference-cross-index)
3. **In Code**: `grep -r "function_name" lib/`

### Finding Configuration Files
1. **By Type**: Use [STRUCTURE.md → File Type Classification](STRUCTURE.md#file-type-classification)
2. **By Security Profile**: Use [Configuration File Cross-Reference](#configuration-file-cross-reference)
3. **In Repository**: `find config/ -name "*.conf" -type f`

### Finding Documentation
1. **Quick Reference**: This navigation guide
2. **Detailed Information**: Cross-references in each section
3. **Implementation Details**: Code comments and function documentation
4. **Usage Examples**: README.md examples section

### Finding Solutions
1. **Common Issues**: [Troubleshooting Cross-Reference](#troubleshooting-cross-reference)
2. **Development Questions**: [CLAUDE.md](../CLAUDE.md) development guidelines
3. **Configuration Questions**: [API.md](API.md) function documentation
4. **Architecture Questions**: [STRUCTURE.md](STRUCTURE.md) component relationships

This navigation guide provides comprehensive cross-references to help you quickly find the information you need, whether you're using, developing, or troubleshooting the Unified Server Setup Framework.