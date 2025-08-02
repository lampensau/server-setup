#!/bin/bash

# Web Server Profile Library - nginx/Caddy with CIS Level 2 Compliance
# Supports static sites, Node.js, PHP, Python with automated certificate management

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Web server configuration variables
readonly NGINX_VERSION_MIN="1.18.0"
readonly CADDY_VERSION_MIN="2.6.0"
readonly DEFAULT_WEB_SERVER="caddy"

# Web Server Profile Main Function
apply_web_profile_complete() {
    info "Applying Web server profile with CIS Level 2 compliance"
    
    # Pre-flight checks
    check_web_prerequisites
    
    # Determine web server choice
    select_web_server
    
    # Core web server installation and hardening
    install_web_server_hardened
    configure_web_server_security
    
    # SSL/TLS and certificate management
    setup_ssl_certificates
    configure_ssl_security
    
    # Application support setup
    setup_application_support
    
    # System-level hardening
    configure_web_apparmor_profiles
    setup_web_systemd_sandboxing
    
    # Monitoring and compliance
    setup_web_monitoring
    configure_web_audit
    
    info "Web server profile configuration complete"
}

# Pre-flight checks for web server installation
check_web_prerequisites() {
    info "Checking web server installation prerequisites"
    
    # Check if port 80/443 are available
    for port in 80 443; do
        if ss -tlpn | grep -q ":$port "; then
            warn "Port $port is already in use - web server may conflict"
        fi
    done
    
    # Check available disk space (web server needs at least 2GB)
    local available_space
    available_space=$(df /var/www 2>/dev/null | tail -1 | awk '{print $4}' || df / | tail -1 | awk '{print $4}')
    if [[ -n "$available_space" && "$available_space" -lt 2097152 ]]; then
        warn "Less than 2GB available for web content - consider disk space management"
    fi
    
    # Check if other web servers are installed
    for web_server in apache2 nginx caddy; do
        if systemctl list-unit-files | grep -q "^${web_server}"; then
            warn "Existing web server detected: $web_server - will need manual cleanup"
        fi
    done
    
    success "Prerequisites check completed"
}

# Select web server based on environment or prompt
select_web_server() {
    local web_server="${WEB_SERVER:-}"
    
    if [[ -z "$web_server" ]]; then
        # Default to Caddy for simplicity unless explicitly overridden
        web_server="$DEFAULT_WEB_SERVER"
        info "No web server specified, defaulting to: $web_server"
    fi
    
    case "$web_server" in
        "nginx"|"caddy")
            export WEB_SERVER="$web_server"
            info "Selected web server: $WEB_SERVER"
            ;;
        *)
            error "Unsupported web server: $web_server. Supported: nginx, caddy"
            return 1
            ;;
    esac
    
    # Export for use in configuration templates
    export WEB_SERVER
}

# Install and configure selected web server
install_web_server_hardened() {
    info "Installing $WEB_SERVER with security hardening"
    
    case "$WEB_SERVER" in
        "nginx")
            install_nginx_hardened
            ;;
        "caddy")
            install_caddy_hardened
            ;;
    esac
}

# nginx Installation with CIS Compliance
install_nginx_hardened() {
    info "Installing nginx with CIS NGINX Benchmark v2.1.0 compliance"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Remove any existing nginx installations
        apt-get remove -y nginx nginx-common nginx-core nginx-full nginx-light 2>/dev/null || true
        
        # Install nginx from official repository for latest security updates
        install_packages nginx-full nginx-extras ssl-cert
        
        # Verify installed version meets minimum requirements
        local installed_version
        installed_version=$(nginx -v 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -1)
        if [[ -n "$installed_version" ]]; then
            if ! version_greater_equal "$installed_version" "$NGINX_VERSION_MIN"; then
                warn "nginx version $installed_version may lack recent security features"
            fi
            info "nginx $installed_version installed successfully"
        fi
        
        # Stop nginx (we'll configure it before starting)
        systemctl stop nginx
        systemctl disable nginx
    else
        info "[DRY RUN] Would install nginx $NGINX_VERSION_MIN+ with CIS compliance"
    fi
    
    success "nginx installation completed"
}

# Caddy Installation with Modern Security
install_caddy_hardened() {
    info "Installing Caddy with automatic HTTPS and security defaults"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Install Caddy from official repository
        install_packages debian-keyring debian-archive-keyring apt-transport-https
        
        # Add Caddy repository
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" > /etc/apt/sources.list.d/caddy-stable.list
        
        # Update and install Caddy
        apt-get update
        install_packages caddy
        
        # Verify installed version
        local installed_version
        installed_version=$(caddy version 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+' | sed 's/v//' | head -1)
        if [[ -n "$installed_version" ]]; then
            if ! version_greater_equal "$installed_version" "$CADDY_VERSION_MIN"; then
                warn "Caddy version $installed_version may lack recent security features"
            fi
            info "Caddy $installed_version installed successfully"
        fi
        
        # Stop Caddy (we'll configure it before starting)
        systemctl stop caddy
        systemctl disable caddy
    else
        info "[DRY RUN] Would install Caddy $CADDY_VERSION_MIN+ with automatic HTTPS"
    fi
    
    success "Caddy installation completed"
}

# Configure web server security based on selection
configure_web_server_security() {
    info "Configuring $WEB_SERVER security settings"
    
    case "$WEB_SERVER" in
        "nginx")
            configure_nginx_security
            ;;
        "caddy")
            configure_caddy_security
            ;;
    esac
}

# nginx Security Configuration (CIS Level 2)
configure_nginx_security() {
    info "Configuring nginx with CIS NGINX Benchmark v2.1.0 Level 2 compliance"
    
    # Create nginx directories
    if [[ "$DRY_RUN" == "false" ]]; then
        mkdir -p /etc/nginx/conf.d
        mkdir -p /etc/nginx/sites-available
        mkdir -p /etc/nginx/sites-enabled
        mkdir -p /etc/nginx/ssl
        mkdir -p /var/www/html
        mkdir -p /var/log/nginx
    fi
    
    # Install main nginx configuration
    atomic_install "$CONFIG_DIR/nginx/nginx.conf" "/etc/nginx/nginx.conf" "644" "root:root"
    
    # Install security configurations
    atomic_install "$CONFIG_DIR/nginx/conf.d/security.conf" "/etc/nginx/conf.d/security.conf" "644" "root:root"
    atomic_install "$CONFIG_DIR/nginx/conf.d/ssl.conf" "/etc/nginx/conf.d/ssl.conf" "644" "root:root"
    
    # Install rate limiting configuration
    atomic_install "$CONFIG_DIR/nginx/conf.d/rate-limiting.conf" "/etc/nginx/conf.d/rate-limiting.conf" "644" "root:root"
    
    # Install NAXSI WAF configuration (ModSecurity replacement)
    if [[ -f "$CONFIG_DIR/nginx/conf.d/naxsi.conf" ]]; then
        atomic_install "$CONFIG_DIR/nginx/conf.d/naxsi.conf" "/etc/nginx/conf.d/naxsi.conf" "644" "root:root"
    fi
    
    # Install default site configuration
    atomic_install "$CONFIG_DIR/nginx/sites/default-secure.conf" "/etc/nginx/sites-available/default" "644" "root:root"
    
    # Enable default site
    if [[ "$DRY_RUN" == "false" ]]; then
        ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
    fi
    
    # Install systemd service override for security
    atomic_install "$CONFIG_DIR/nginx/systemd/nginx.service.d/override.conf" \
                   "/etc/systemd/system/nginx.service.d/override.conf" "644" "root:root"
    
    success "nginx security configuration applied"
}

# Caddy Security Configuration
configure_caddy_security() {
    info "Configuring Caddy with secure defaults and hardening"
    
    # Create Caddy directories
    if [[ "$DRY_RUN" == "false" ]]; then
        mkdir -p /etc/caddy
        mkdir -p /var/www/html
        mkdir -p /var/log/caddy
        mkdir -p /var/lib/caddy/.local/share/caddy
    fi
    
    # Install main Caddyfile
    atomic_install "$CONFIG_DIR/caddy/Caddyfile" "/etc/caddy/Caddyfile" "644" "caddy:caddy"
    
    # Install Caddy security configuration
    atomic_install "$CONFIG_DIR/caddy/conf.d/security.caddy" "/etc/caddy/conf.d/security.caddy" "644" "caddy:caddy"
    
    # Install systemd service override for security
    atomic_install "$CONFIG_DIR/caddy/systemd/caddy.service.d/override.conf" \
                   "/etc/systemd/system/caddy.service.d/override.conf" "644" "root:root"
    
    success "Caddy security configuration applied"
}

# SSL/TLS Certificate Setup
setup_ssl_certificates() {
    info "Setting up SSL/TLS certificates with Let's Encrypt"
    
    # Install certbot for manual certificate management
    if [[ "$DRY_RUN" == "false" ]]; then
        install_packages certbot python3-certbot-nginx python3-certbot-dns-cloudflare
    fi
    
    # Install certificate management scripts
    atomic_install "$CONFIG_DIR/web/ssl/cert-renewal.sh" "/usr/local/bin/cert-renewal.sh" "755" "root:root"
    atomic_install "$CONFIG_DIR/web/ssl/cert-backup.sh" "/usr/local/bin/cert-backup.sh" "755" "root:root"
    
    # Install certificate renewal timer
    atomic_install "$CONFIG_DIR/web/systemd/cert-renewal.timer" "/etc/systemd/system/cert-renewal.timer" "644" "root:root"
    atomic_install "$CONFIG_DIR/web/systemd/cert-renewal.service" "/etc/systemd/system/cert-renewal.service" "644" "root:root"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        systemctl enable cert-renewal.timer
    fi
    
    success "SSL certificate management configured"
}

# Configure SSL/TLS Security Settings
configure_ssl_security() {
    info "Configuring SSL/TLS security with modern cipher suites"
    
    # Generate DH parameters for nginx if selected
    if [[ "$WEB_SERVER" == "nginx" && "$DRY_RUN" == "false" ]]; then
        if [[ ! -f /etc/nginx/ssl/dhparam.pem ]]; then
            info "Generating DH parameters (this may take a while)..."
            openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048
            chmod 600 /etc/nginx/ssl/dhparam.pem
        fi
    fi
    
    # Install HSTS and security headers configuration
    case "$WEB_SERVER" in
        "nginx")
            atomic_install "$CONFIG_DIR/nginx/conf.d/security-headers.conf" \
                           "/etc/nginx/conf.d/security-headers.conf" "644" "root:root"
            ;;
        "caddy")
            # Caddy handles security headers automatically, but we can customize
            atomic_install "$CONFIG_DIR/caddy/conf.d/headers.caddy" \
                           "/etc/caddy/conf.d/headers.caddy" "644" "caddy:caddy"
            ;;
    esac
    
    success "SSL/TLS security configuration applied"
}

# Setup application support (Node.js, PHP, Python)
setup_application_support() {
    info "Setting up application support for Node.js, PHP, Python"
    
    # Install application runtimes based on WEB_APPS environment variable
    local web_apps="${WEB_APPS:-static}"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Always install basic tools
        install_packages curl wget unzip git
        
        if [[ "$web_apps" == *"php"* ]]; then
            install_packages php-fpm php-cli php-curl php-gd php-mbstring php-xml php-zip
            configure_php_security
        fi
        
        if [[ "$web_apps" == *"nodejs"* ]]; then
            install_nodejs_lts
            configure_nodejs_pm2
        fi
        
        if [[ "$web_apps" == *"python"* ]]; then
            install_packages python3 python3-pip python3-venv
            configure_python_wsgi
        fi
    else
        info "[DRY RUN] Would install application support for: $web_apps"
    fi
    
    # Install application-specific configurations
    case "$WEB_SERVER" in
        "nginx")
            install_nginx_app_configs
            ;;
        "caddy")
            install_caddy_app_configs
            ;;
    esac
    
    success "Application support configured"
}

# Configure PHP-FPM security
configure_php_security() {
    info "Configuring PHP-FPM with security hardening"
    
    # Install hardened PHP-FPM configuration
    atomic_install "$CONFIG_DIR/web/php/www.conf" "/etc/php/$(php -r 'echo PHP_MAJOR_VERSION.\".\".PHP_MINOR_VERSION;')/fpm/pool.d/www.conf" "644" "root:root"
    atomic_install "$CONFIG_DIR/web/php/php-security.ini" "/etc/php/$(php -r 'echo PHP_MAJOR_VERSION.\".\".PHP_MINOR_VERSION;')/fpm/conf.d/99-security.ini" "644" "root:root"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        systemctl enable php*-fpm
    fi
}

# Install Node.js LTS
install_nodejs_lts() {
    info "Installing Node.js LTS with security configuration"
    
    # Install Node.js from official repository
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    install_packages nodejs
    
    # Install PM2 for process management
    npm install -g pm2
    
    # Configure PM2 security
    if [[ -f "$CONFIG_DIR/web/nodejs/pm2.config.js" ]]; then
        atomic_install "$CONFIG_DIR/web/nodejs/pm2.config.js" "/etc/pm2/pm2.config.js" "644" "www-data:www-data"
    fi
}

# Configure Python WSGI
configure_python_wsgi() {
    info "Configuring Python WSGI with security settings"
    
    # Install Gunicorn for Python applications
    pip3 install gunicorn
    
    # Install Gunicorn configuration
    atomic_install "$CONFIG_DIR/web/python/gunicorn.conf.py" "/etc/gunicorn/gunicorn.conf.py" "644" "www-data:www-data"
}

# Install nginx application configurations
install_nginx_app_configs() {
    info "Installing nginx application configurations"
    
    # Install site templates for different application types
    for app_type in static php nodejs python; do
        if [[ -f "$CONFIG_DIR/nginx/sites/${app_type}.conf.template" ]]; then
            atomic_install "$CONFIG_DIR/nginx/sites/${app_type}.conf.template" \
                           "/etc/nginx/sites-available/${app_type}.conf.template" "644" "root:root"
        fi
    done
    
    # Install deployment script
    atomic_install "$CONFIG_DIR/web/scripts/deploy-nginx-site.sh" "/usr/local/bin/deploy-nginx-site" "755" "root:root"
}

# Install Caddy application configurations
install_caddy_app_configs() {
    info "Installing Caddy application configurations"
    
    # Install site templates for different application types
    for app_type in static php nodejs python; do
        if [[ -f "$CONFIG_DIR/caddy/sites/${app_type}.caddy.template" ]]; then
            atomic_install "$CONFIG_DIR/caddy/sites/${app_type}.caddy.template" \
                           "/etc/caddy/sites/${app_type}.caddy.template" "644" "caddy:caddy"
        fi
    done
    
    # Install deployment script
    atomic_install "$CONFIG_DIR/web/scripts/deploy-caddy-site.sh" "/usr/local/bin/deploy-caddy-site" "755" "root:root"
}

# Configure AppArmor profiles for web servers
configure_web_apparmor_profiles() {
    info "Configuring AppArmor profiles for web server security"
    
    if ! command -v apparmor_status >/dev/null 2>&1; then
        warn "AppArmor not available - skipping web server AppArmor profiles"
        return 0
    fi
    
    case "$WEB_SERVER" in
        "nginx")
            atomic_install "$CONFIG_DIR/web/apparmor/nginx.profile" "/etc/apparmor.d/nginx" "644" "root:root"
            if [[ "$DRY_RUN" == "false" ]]; then
                apparmor_parser -r /etc/apparmor.d/nginx
            fi
            ;;
        "caddy")
            atomic_install "$CONFIG_DIR/web/apparmor/caddy.profile" "/etc/apparmor.d/caddy" "644" "root:root"
            if [[ "$DRY_RUN" == "false" ]]; then
                apparmor_parser -r /etc/apparmor.d/caddy
            fi
            ;;
    esac
    
    success "AppArmor profiles configured for web server"
}

# Setup systemd sandboxing for web services
setup_web_systemd_sandboxing() {
    info "Setting up systemd sandboxing for web services"
    
    # The service overrides are already installed in configure_*_security functions
    # This function can be used for additional systemd hardening if needed
    
    success "Systemd sandboxing configured"
}

# Setup web server monitoring
setup_web_monitoring() {
    info "Setting up web server monitoring and logging"
    
    # Install log rotation for web servers
    case "$WEB_SERVER" in
        "nginx")
            atomic_install "$CONFIG_DIR/web/logging/nginx-logrotate.conf" "/etc/logrotate.d/nginx" "644" "root:root"
            ;;
        "caddy")
            atomic_install "$CONFIG_DIR/web/logging/caddy-logrotate.conf" "/etc/logrotate.d/caddy" "644" "root:root"
            ;;
    esac
    
    # Install fail2ban configuration for web servers
    atomic_install "$CONFIG_DIR/web/fail2ban/web-${WEB_SERVER}.conf" "/etc/fail2ban/jail.d/web-${WEB_SERVER}.conf" "644" "root:root"
    
    # Install monitoring scripts
    atomic_install "$CONFIG_DIR/web/scripts/web-audit.sh" "/usr/local/bin/web-audit.sh" "755" "root:root"
    atomic_install "$CONFIG_DIR/web/scripts/ssl-check.sh" "/usr/local/bin/ssl-check.sh" "755" "root:root"
    
    success "Web server monitoring configured"
}

# Configure web server audit and compliance
configure_web_audit() {
    info "Configuring web server audit and CIS compliance checking"
    
    if [[ "$SECURITY_PROFILE" == "hardened" ]]; then
        # Install weekly CIS compliance check
        if [[ "$WEB_SERVER" == "nginx" ]]; then
            atomic_install "$CONFIG_DIR/web/audit/nginx-cis-check.sh" "/usr/local/bin/nginx-cis-check" "755" "root:root"
            
            if [[ "$DRY_RUN" == "false" ]]; then
                # Create weekly cron job for CIS compliance check
                cat > /etc/cron.d/nginx-cis-audit << 'EOF'
# Weekly nginx CIS compliance audit
0 3 * * 1 root /usr/local/bin/nginx-cis-check > /var/log/nginx-cis-$(date +\%Y\%m\%d).log 2>&1
EOF
                chmod 644 /etc/cron.d/nginx-cis-audit
            fi
        fi
    fi
    
    success "Web server audit and compliance configured"
}

# Start web services
start_web_services() {
    info "Starting web server services"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Reload systemd configuration
        systemctl daemon-reload
        
        # Start and enable web server
        systemctl enable "$WEB_SERVER"
        systemctl start "$WEB_SERVER"
        
        # Start PHP-FPM if PHP is configured
        if [[ "${WEB_APPS:-}" == *"php"* ]]; then
            systemctl enable php*-fpm
            systemctl start php*-fpm
        fi
        
        # Verify web server is running
        if systemctl is-active --quiet "$WEB_SERVER"; then
            success "$WEB_SERVER service started successfully"
        else
            error "Failed to start $WEB_SERVER service"
            return 1
        fi
        
        # Test web server configuration
        case "$WEB_SERVER" in
            "nginx")
                if nginx -t >/dev/null 2>&1; then
                    success "nginx configuration test passed"
                else
                    error "nginx configuration test failed"
                    return 1
                fi
                ;;
            "caddy")
                if caddy validate --config /etc/caddy/Caddyfile >/dev/null 2>&1; then
                    success "Caddy configuration test passed"
                else
                    error "Caddy configuration test failed"
                    return 1
                fi
                ;;
        esac
    else
        info "[DRY RUN] Would start $WEB_SERVER services and verify configuration"
    fi
    
    success "Web services started and verified"
}

# Test web server configuration
test_web_config() {
    info "Testing web server configuration"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        local test_failures=0
        
        # Test web server is responding
        if ! curl -s --max-time 10 http://localhost >/dev/null; then
            error "Web server is not responding on port 80"
            ((test_failures++))
        else
            success "✓ Web server responding on port 80"
        fi
        
        # Test SSL configuration if available
        if ss -tlpn | grep -q ":443 "; then
            if curl -s --max-time 10 https://localhost -k >/dev/null; then
                success "✓ SSL/TLS responding on port 443"
            else
                warn "⚠ SSL/TLS not responding properly"
                ((test_failures++))
            fi
        fi
        
        # Test configuration syntax
        case "$WEB_SERVER" in
            "nginx")
                if nginx -t >/dev/null 2>&1; then
                    success "✓ nginx configuration syntax valid"
                else
                    error "✗ nginx configuration syntax errors"
                    ((test_failures++))
                fi
                ;;
            "caddy")
                if caddy validate --config /etc/caddy/Caddyfile >/dev/null 2>&1; then
                    success "✓ Caddy configuration syntax valid"
                else
                    error "✗ Caddy configuration syntax errors"
                    ((test_failures++))
                fi
                ;;
        esac
        
        # Test security headers
        if command -v curl >/dev/null 2>&1; then
            local security_headers=("X-Frame-Options" "X-Content-Type-Options" "X-XSS-Protection")
            for header in "${security_headers[@]}"; do
                if curl -s -I http://localhost | grep -qi "$header"; then
                    success "✓ Security header present: $header"
                else
                    warn "⚠ Security header missing: $header"
                fi
            done
        fi
        
        # Summary
        if [[ $test_failures -eq 0 ]]; then
            success "Web server configuration tests passed"
        else
            warn "Web server configuration has $test_failures issues"
        fi
    else
        info "[DRY RUN] Would test web server configuration and security"
    fi
}

# Show web server status
show_web_status() {
    info "=== Web Server Status ==="
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Web server version and status
        echo "Web Server: $WEB_SERVER"
        case "$WEB_SERVER" in
            "nginx")
                local nginx_version
                nginx_version=$(nginx -v 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -1)
                echo "Version: ${nginx_version:-Unknown}"
                ;;
            "caddy")
                local caddy_version
                caddy_version=$(caddy version 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+' | sed 's/v//' | head -1)
                echo "Version: ${caddy_version:-Unknown}"
                ;;
        esac
        
        # Service status
        echo "Service Status: $(systemctl is-active "$WEB_SERVER" 2>/dev/null || echo 'inactive')"
        
        # Port status
        if ss -tlpn | grep -q ":80 "; then
            echo "HTTP (80): ✓ Listening"
        else
            echo "HTTP (80): ⚠ Not listening"
        fi
        
        if ss -tlpn | grep -q ":443 "; then
            echo "HTTPS (443): ✓ Listening"
        else
            echo "HTTPS (443): ⚠ Not listening"
        fi
        
        # Domain and URL information
        local domain="${DOMAIN:-localhost}"
        if [[ "$domain" == "localhost" ]]; then
            echo "Local URL: http://localhost"
            echo "Note: Configure DOMAIN variable for public access"
        else
            echo "Public URL: https://$domain"
        fi
        
        # Application support
        echo ""
        echo "Application Support:"
        local web_apps="${WEB_APPS:-static}"
        for app in static php nodejs python; do
            if [[ "$web_apps" == *"$app"* ]]; then
                echo "  $app: ✓ Configured"
            else
                echo "  $app: - Not configured"
            fi
        done
        
        # SSL certificate status
        if [[ -n "${DOMAIN:-}" && "$DOMAIN" != "localhost" ]]; then
            if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
                local cert_expiry
                cert_expiry=$(openssl x509 -enddate -noout -in "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" 2>/dev/null | cut -d= -f2)
                echo "SSL Certificate: ✓ Active (expires: $cert_expiry)"
            else
                echo "SSL Certificate: ⚠ Not found (run: certbot certonly --$WEB_SERVER -d $DOMAIN)"
            fi
        fi
        
        # CIS compliance reminder
        if [[ "$WEB_SERVER" == "nginx" && "$SECURITY_PROFILE" == "hardened" ]]; then
            echo ""
            echo "CIS Compliance: Run /usr/local/bin/nginx-cis-check for detailed audit"
        fi
        
    else
        echo "[DRY RUN] Web server status information would be displayed here"
    fi
}