#!/bin/bash

# nginx Site Deployment Script
# Deploy new sites with automatic SSL certificate generation

set -euo pipefail

# Script configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly SITES_AVAILABLE="/etc/nginx/sites-available"
readonly SITES_ENABLED="/etc/nginx/sites-enabled"
readonly WEB_ROOT="/var/www"
readonly LOG_DIR="/var/log/nginx"
readonly TEMPLATE_DIR="/etc/nginx/sites"

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Usage information
usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] <domain> <type>

Deploy nginx site configuration with automatic SSL

Arguments:
  domain    Domain name (e.g., example.com)
  type      Site type: static, php, nodejs, python

Options:
  -r, --root <path>     Document root (default: /var/www/<domain>)
  -e, --email <email>   Email for Let's Encrypt (default: webmaster@<domain>)
  --php-version <ver>   PHP version for PHP sites (default: 8.1)
  --port <port>         Backend port for proxy sites (default: 3000)
  --dry-run            Show what would be done without executing
  -h, --help           Show this help message

Examples:
  $SCRIPT_NAME example.com static
  $SCRIPT_NAME blog.example.com php --php-version 8.2
  $SCRIPT_NAME app.example.com nodejs --port 3000
EOF
    exit 1
}

# Parse command line arguments
DOMAIN=""
SITE_TYPE=""
DOCUMENT_ROOT=""
EMAIL=""
PHP_VERSION="8.1"
BACKEND_PORT="3000"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--root)
            DOCUMENT_ROOT="$2"
            shift 2
            ;;
        -e|--email)
            EMAIL="$2"
            shift 2
            ;;
        --php-version)
            PHP_VERSION="$2"
            shift 2
            ;;
        --port)
            BACKEND_PORT="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [[ -z "$DOMAIN" ]]; then
                DOMAIN="$1"
            elif [[ -z "$SITE_TYPE" ]]; then
                SITE_TYPE="$1"
            else
                log_error "Unknown argument: $1"
                usage
            fi
            shift
            ;;
    esac
done

# Validate arguments
if [[ -z "$DOMAIN" || -z "$SITE_TYPE" ]]; then
    log_error "Domain and site type are required"
    usage
fi

if [[ ! "$SITE_TYPE" =~ ^(static|php|nodejs|python)$ ]]; then
    log_error "Invalid site type: $SITE_TYPE. Must be static, php, nodejs, or python"
    exit 1
fi

# Set defaults
DOCUMENT_ROOT="${DOCUMENT_ROOT:-$WEB_ROOT/$DOMAIN}"
EMAIL="${EMAIL:-webmaster@$DOMAIN}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
fi

# Check if domain already exists
if [[ -f "$SITES_AVAILABLE/$DOMAIN" ]]; then
    log_error "Site $DOMAIN already exists"
    exit 1
fi

# Check if template exists
TEMPLATE_FILE="$TEMPLATE_DIR/${SITE_TYPE}.conf.template"
if [[ ! -f "$TEMPLATE_FILE" ]]; then
    log_error "Template not found: $TEMPLATE_FILE"
    exit 1
fi

# Main deployment function
deploy_site() {
    log_info "Deploying $SITE_TYPE site: $DOMAIN"
    
    # Create document root
    if [[ "$DRY_RUN" == "false" ]]; then
        mkdir -p "$DOCUMENT_ROOT"
        chown www-data:www-data "$DOCUMENT_ROOT"
        chmod 755 "$DOCUMENT_ROOT"
        log_info "Created document root: $DOCUMENT_ROOT"
    else
        log_info "[DRY RUN] Would create document root: $DOCUMENT_ROOT"
    fi
    
    # Create nginx configuration from template
    if [[ "$DRY_RUN" == "false" ]]; then
        export DOMAIN DOCUMENT_ROOT PHP_VERSION BACKEND_PORT
        envsubst < "$TEMPLATE_FILE" > "$SITES_AVAILABLE/$DOMAIN"
        log_info "Created nginx configuration: $SITES_AVAILABLE/$DOMAIN"
    else
        log_info "[DRY RUN] Would create nginx configuration from template"
    fi
    
    # Test nginx configuration
    if [[ "$DRY_RUN" == "false" ]]; then
        if nginx -t; then
            log_info "nginx configuration test passed"
        else
            log_error "nginx configuration test failed"
            rm -f "$SITES_AVAILABLE/$DOMAIN"
            exit 1
        fi
    else
        log_info "[DRY RUN] Would test nginx configuration"
    fi
    
    # Enable site
    if [[ "$DRY_RUN" == "false" ]]; then
        ln -sf "$SITES_AVAILABLE/$DOMAIN" "$SITES_ENABLED/$DOMAIN"
        systemctl reload nginx
        log_info "Enabled and reloaded nginx"
    else
        log_info "[DRY RUN] Would enable site and reload nginx"
    fi
    
    # Create default content if static site
    if [[ "$SITE_TYPE" == "static" ]]; then
        create_default_content
    fi
    
    # Obtain SSL certificate
    obtain_ssl_certificate
    
    # Final nginx reload
    if [[ "$DRY_RUN" == "false" ]]; then
        systemctl reload nginx
        log_info "Final nginx reload completed"
    else
        log_info "[DRY RUN] Would perform final nginx reload"
    fi
}

# Create default content for static sites
create_default_content() {
    local index_file="$DOCUMENT_ROOT/index.html"
    
    if [[ "$DRY_RUN" == "false" && ! -f "$index_file" ]]; then
        cat > "$index_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to $DOMAIN</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
        .header { text-align: center; color: #333; }
        .status { background: #e8f5e8; padding: 15px; border-radius: 5px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Welcome to $DOMAIN</h1>
        <p>Your nginx server is working correctly!</p>
    </div>
    <div class="status">
        <h3>Site Information:</h3>
        <ul>
            <li>Domain: $DOMAIN</li>
            <li>Type: $SITE_TYPE</li>
            <li>Document Root: $DOCUMENT_ROOT</li>
            <li>SSL: Automatically managed by Let's Encrypt</li>
        </ul>
    </div>
    <p>You can now replace this default page with your own content.</p>
</body>
</html>
EOF
        chown www-data:www-data "$index_file"
        log_info "Created default index page"
    elif [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create default index page"
    fi
}

# Obtain SSL certificate using certbot
obtain_ssl_certificate() {
    log_info "Obtaining SSL certificate for $DOMAIN"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        if certbot certonly --nginx -d "$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive; then
            log_info "SSL certificate obtained successfully"
        else
            log_warn "Failed to obtain SSL certificate - site will use self-signed certificate"
        fi
    else
        log_info "[DRY RUN] Would obtain SSL certificate using certbot"
    fi
}

# Main execution
main() {
    log_info "Starting deployment of $DOMAIN ($SITE_TYPE)"
    deploy_site
    
    echo ""
    log_info "Deployment completed successfully!"
    log_info "Site URL: https://$DOMAIN"
    log_info "Document Root: $DOCUMENT_ROOT"
    log_info "nginx Config: $SITES_AVAILABLE/$DOMAIN"
    log_info "Logs: $LOG_DIR/$DOMAIN.*.log"
}

# Run main function
main "$@"