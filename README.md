# Unified Server Setup Script

Comprehensive server configuration script that combines SSH hardening, system security, and specialized server types into a single, unified solution. This script provides a streamlined approach for configuring secure, hardened servers with support for Docker, web servers, and bare metal installations.

## Overview

The unified server setup script provides:
- **Multiple Server Types**: Bare metal, Docker with Coolify, and web servers (nginx/Caddy)
- **SSH Server & Client Configuration**: Modern SSH security with ED25519 keys, secure algorithms, and fail2ban protection
- **System Hardening**: Kernel parameters, security policies, and system optimization
- **Web Server Security**: CIS Level 2 compliance for nginx, secure-by-default Caddy configuration
- **Flexible Security Profiles**: Minimal, standard, and hardened configurations
- **Modular Architecture**: Choose system-only, SSH-only, or combined setup
- **Safety Features**: Comprehensive backup, rollback, and dry-run capabilities

## Quick Start

```bash
# Full server setup with default security profile
sudo ./server-setup.sh

# Docker server with Coolify and maximum security
sudo ./server-setup.sh -t docker -s hardened

# Web server with nginx and CIS compliance
sudo ./server-setup.sh -t web

# SSH hardening only with custom port
sudo ./server-setup.sh -m ssh -p 2222

# Dry run to see what would be changed
sudo ./server-setup.sh -d
```

## Command Reference

### Basic Usage

```bash
./server-setup.sh [OPTIONS]
```

### Options

- `-m, --mode <mode>` - Setup mode: 'system', 'ssh', 'both' (default: both)
- `-t, --type <type>` - Server type: 'bare', 'docker', 'web' (default: bare)
- `-s, --security <profile>` - Security profile: 'minimal', 'standard', 'hardened' (default: standard)
- `-p, --ssh-port <port>` - SSH port (default: 22)
- `--ssh-mode <mode>` - SSH setup: 'server', 'client', 'both' (default: both)
- `-u, --admin-user <user>` - Create admin user with sudo access
- `--no-admin-password` - Skip password setup for admin user
- `-d, --dry-run` - Enable dry-run mode
- `-h, --help` - Display help message

### Setup Modes

- **`system`** - System hardening and optimization only
- **`ssh`** - SSH configuration and security only
- **`both`** - Complete server setup (system + SSH)

### Server Types

- **`bare`** - Basic hardened server (default)
- **`docker`** - Docker + Coolify with maximum security hardening
- **`web`** - Web server (nginx/Caddy) with CIS Level 2 compliance

### Security Profiles

- **`minimal`** - Basic security measures only
- **`standard`** - Recommended security hardening (default)
- **`hardened`** - Maximum security with strict policies

## Directory Structure

```
server-setup/
├── server-setup.sh              # Main unified script
├── README.md                    # This documentation
├── local.conf.example           # Configuration template
├── lib/                         # Library modules
│   ├── common.sh               # Shared utilities
│   ├── security.sh             # Security hardening
│   ├── system.sh               # System configuration
│   ├── ssh-server.sh           # SSH server setup
│   ├── ssh-client.sh           # SSH client setup
│   ├── admin-user.sh           # Admin user management
│   ├── docker.sh               # Docker + Coolify setup
│   └── web.sh                  # Web server setup
├── config/                     # Configuration files
│   ├── system/                 # System-level configurations
│   │   ├── sysctl/            # Kernel parameters
│   │   ├── systemd/           # Systemd configurations
│   │   ├── network/           # Network configurations
│   │   └── udev/              # Device rules
│   ├── security/              # Security configurations
│   │   ├── apparmor/          # AppArmor profiles
│   │   ├── fail2ban/          # Fail2ban jails
│   │   ├── firewall/          # iptables/ufw rules
│   │   ├── limits/            # System limits
│   │   └── hardening/         # General hardening
│   ├── ssh/                   # SSH-specific configurations
│   │   ├── server/            # sshd configs
│   │   ├── client/            # ssh client configs
│   │   └── services/          # autossh, etc.
│   ├── docker/                # Docker + Coolify configurations
│   │   ├── daemon/            # Docker daemon configs
│   │   ├── security/          # AppArmor, seccomp profiles
│   │   ├── networking/        # Docker network configs
│   │   └── monitoring/        # Docker audit and logging
│   ├── nginx/                 # nginx configurations
│   │   ├── conf.d/           # Security and SSL configs
│   │   ├── sites/            # Site templates
│   │   └── systemd/          # Service hardening
│   ├── caddy/                 # Caddy configurations
│   │   ├── conf.d/           # Security snippets
│   │   ├── sites/            # Site templates
│   │   └── systemd/          # Service hardening
│   ├── web/                   # Shared web server configs
│   │   ├── ssl/              # Certificate management
│   │   ├── php/              # PHP-FPM security
│   │   ├── scripts/          # Deployment tools
│   │   ├── apparmor/         # Web server profiles
│   │   ├── fail2ban/         # Web protection
│   │   └── audit/            # CIS compliance
│   ├── applications/          # Application-specific configs
│   │   ├── apt/               # Package management
│   │   └── logging/           # Log rotation
│   └── scripts/               # Management scripts
│       ├── ssh/               # SSH management tools
│       ├── security/          # Security tools
│       └── monitoring/        # Monitoring scripts
```

## Features

### Server Types

#### Docker Server (`-t docker`)

- **Docker CE Installation**: Latest Docker with CVE-2024-41110 protection
- **Coolify Integration**: Container management platform with automatic HTTPS
- **Maximum Security**: User namespace remapping, AppArmor profiles, seccomp filtering
- **Network Isolation**: Three-tier network architecture (DMZ, app, data)
- **Compliance**: 80-85% CIS Docker Benchmark Level 1 coverage
- **Monitoring**: Comprehensive audit logging and security scanning

#### Web Server (`-t web`)

- **Dual Engine Support**: Choice between nginx (granular control) or Caddy (secure-by-default)
- **CIS Level 2 Compliance**: Full CIS NGINX Benchmark v2.1.0 implementation
- **Automatic HTTPS**: Let's Encrypt integration with certificate management
- **Application Support**: Static sites, PHP, Node.js, Python with security hardening
- **Modern Security**: TLS 1.3, HSTS, CSP, security headers, rate limiting
- **SystemD Sandboxing**: Comprehensive process isolation and security

#### Bare Server (`-t bare`)

- **Minimal Base**: Essential hardening without additional services
- **Foundation**: Perfect base for custom application deployment
- **Security Focus**: Core system hardening and SSH security only

### SSH Configuration

- **Modern Cryptography**: ED25519 keys only, secure algorithms
- **Server Hardening**: Disable weak authentication, protocol restrictions
- **Client Optimization**: ControlMaster, connection multiplexing
- **Fail2ban Protection**: Automatic IP blocking for failed attempts
- **SFTP Support**: Secure file transfer configuration

### System Hardening

- **Kernel Security**: Optimized sysctl parameters for security
- **Process Limits**: Resource constraints and security limits
- **Network Security**: Firewall configuration and protocol restrictions
- **Logging**: Persistent journald and structured log rotation
- **Package Management**: Production APT configuration and unattended upgrades

### Security Profiles

#### Minimal Profile

- Basic kernel security parameters
- Disable core dumps
- Basic fail2ban configuration
- Essential security measures only

#### Standard Profile (Default)

- Enhanced kernel security parameters
- Basic firewall configuration
- Process accounting for auditing
- Unattended security updates
- Balanced security without operational complexity

#### Hardened Profile

- Maximum security kernel parameters
- Advanced fail2ban configuration
- AppArmor enforcement
- Unused protocol blacklisting
- Secure mount options
- Strict resource limits

## Safety Features

### Backup and Recovery

- **Automatic Backups**: All configurations backed up before changes
- **Rollback Scripts**: One-command restoration capability
- **Backup Location**: `/root/server-backup-TIMESTAMP/`
- **Restore Command**: `$BACKUP_DIR/restore.sh`

### Validation

- **Configuration Testing**: All configs tested before application
- **SSH Safety**: Prevents SSH lockout during remote configuration
- **Dry Run Mode**: Preview all changes without applying them
- **Dependency Checking**: Verifies all required tools are available

### Error Handling

- **Graceful Failures**: Comprehensive error handling and reporting
- **Detailed Logging**: All operations logged to `/var/log/server-setup.log`
- **Service Continuity**: Critical services protected during configuration

## Examples

### Common Scenarios

**Basic Server Setup**

```bash
# Default setup with standard security
sudo ./server-setup.sh
```

**SSH-Only Hardening**

```bash
# Harden SSH with custom port
sudo ./server-setup.sh -m ssh -p 2222 -s hardened
```

**Maximum Security**

```bash
# Full hardened setup
sudo ./server-setup.sh -s hardened
```

**Web Server with nginx**

```bash
# nginx web server with PHP support
WEB_SERVER=nginx WEB_APPS=static,php sudo ./server-setup.sh -t web -s hardened
```

**Docker Development**

```bash
# Docker server for development
sudo ./server-setup.sh -t docker -u developer
```

**Development Environment**

```bash
# Minimal security for dev work
sudo ./server-setup.sh -s minimal
```

**Client-Only Setup**

```bash
# Configure SSH client only
sudo ./server-setup.sh -m ssh --ssh-mode client
```

## Post-Installation

### Verification

The script automatically runs verification tests and displays status information. Key areas to verify:

1. **SSH Access**: Test new SSH configuration before disconnecting
2. **Service Status**: Verify critical services are running
3. **Security Settings**: Review applied security configurations
4. **Log Files**: Check `/var/log/server-setup.log` for any issues

### Audit Tools

- **SSH Audit**: `/usr/local/bin/ssh-audit.sh` (if SSH mode enabled)
- **Web Server Audit**: `/usr/local/bin/web-audit.sh` (if web type enabled)
- **nginx CIS Check**: `/usr/local/bin/nginx-cis-check` (hardened profile)
- **Docker Security**: Weekly Docker Bench security scans (hardened profile)
- **System Status**: Built-in status display shows key metrics
- **Security Review**: Configuration summaries in log file

### Reboot Recommendation

A system reboot is recommended after configuration to ensure all changes take effect, especially:

- Kernel parameter changes
- Security module updates
- Service configuration changes

## Customization

### Local Configuration

Create `local.conf` in the script directory to override defaults. See `local.conf.example` for all available parameters:

```bash
# Copy example and customize
cp local.conf.example local.conf

# Example configurations:

# Web server with nginx and PHP
WEB_SERVER="nginx"
WEB_APPS="static,php"
DOMAIN="example.com"
PHP_VERSION="8.2"

# Docker server configuration
DOMAIN="docker.example.com"
COOLIFY_DOMAIN="docker.example.com"

# Custom timezone and hostname
TIMEZONE="Europe/Berlin"
HOSTNAME="web01"
DOMAIN="example.com"

# High-security SSH configuration
SSH_PORT="2222"
ALLOW_AGENT_FORWARDING="no"
ALLOW_TCP_FORWARDING="no"
```

Key configuration categories:

- **System**: Timezone, hostname, IPv6 settings
- **SSH**: Port, forwarding, user management
- **Web Server**: Engine selection, applications, SSL
- **Docker**: Coolify domain, security settings
- **Security**: Package removal, firewall rules
- **Monitoring**: Log retention, audit tools

### Package Removal

Create `packages-remove.conf` to specify additional packages to remove in hardened mode:

```
# One package per line, comments with #
unwanted-package
another-package
```

## Web Server Management

### Site Deployment

```bash
# Deploy nginx site
/usr/local/bin/deploy-nginx-site example.com static

# Deploy PHP site with custom version
/usr/local/bin/deploy-nginx-site blog.example.com php --php-version 8.2

# Deploy Node.js application
/usr/local/bin/deploy-nginx-site app.example.com nodejs --port 3000
```

### SSL Certificate Management

```bash
# Obtain certificate for nginx site
certbot certonly --nginx -d example.com

# Obtain certificate for Caddy (automatic)
# Caddy handles certificates automatically with ACME

# Manual certificate renewal
/usr/local/bin/cert-renewal.sh

# Certificate backup
/usr/local/bin/cert-backup.sh
```

### Web Server Configuration

- **nginx**: Manual configuration with CIS compliance checking
- **Caddy**: Automatic HTTPS with secure defaults
- **Applications**: Template-based deployment for common stacks
- **Security**: Fail2ban protection, rate limiting, security headers

## Docker Management

### Coolify Platform

After Docker installation, Coolify provides a web interface for container management:

- **URL**: `https://your-domain` or `http://localhost:8000`
- **Features**: Git-based deployments, automatic SSL, monitoring
- **Security**: Hardened configuration with AppArmor and network isolation

### Docker Commands

```bash
# Check Docker security status
docker info

# View security features
docker run --rm --security-opt no-new-privileges:true alpine echo "Security test"

# Monitor container security
docker run --rm docker/docker-bench-security
```

## Compatibility

- ✅ Debian 10, 11, 12
- ✅ Ubuntu 18.04, 20.04, 22.04, 24.04
- ✅ Virtual machines (KVM, VMware, VirtualBox)
- ✅ Cloud instances (AWS, GCP, Azure)
- ✅ Docker/Podman compatibility
- ⚠️ Containers (limited functionality)

## Requirements

### Base System

- Debian/Ubuntu with systemd
- Root privileges
- Internet connection for package updates
- Minimum 2GB RAM, 10GB disk space

### Service-Specific

- **SSH Mode**: OpenSSH 7.9+
- **Docker Type**: 4GB RAM recommended, 20GB disk space
- **Web Type**: Domain name for SSL certificates (optional)

## Support

For issues, questions, or contributions:
- Review log files in `/var/log/server-setup.log`
- Check backup location for rollback options
- Use dry-run mode to troubleshoot configuration issues
- Verify system compatibility and requirements