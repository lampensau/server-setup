#!/bin/bash

# Docker Security Monitor
# Monitors Docker security configuration and generates alerts

set -euo pipefail

# Configuration
LOG_FILE="/var/log/docker-audit/security-monitor.log"
ALERT_THRESHOLD_HIGH=5
ALERT_THRESHOLD_CRITICAL=10
DOCKER_DAEMON_JSON="/etc/docker/daemon.json"

# Logging functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

log_error() {
    log "ERROR: $*" >&2
}

log_warn() {
    log "WARNING: $*"
}

log_info() {
    log "INFO: $*"
}

# Check if Docker is running
check_docker_status() {
    if ! systemctl is-active --quiet docker; then
        log_error "Docker service is not running"
        return 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not accessible"
        return 1
    fi
    
    log_info "Docker service is running and accessible"
    return 0
}

# Check Docker daemon configuration
check_daemon_config() {
    local issues=0
    
    if [[ ! -f "$DOCKER_DAEMON_JSON" ]]; then
        log_error "Docker daemon.json not found"
        ((issues++))
        return $issues
    fi
    
    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        log_warn "jq not available - skipping daemon configuration checks"
        return 0
    fi
    
    # Validate JSON syntax
    if ! jq . "$DOCKER_DAEMON_JSON" >/dev/null 2>&1; then
        log_error "Invalid JSON in daemon.json"
        ((issues++))
        return $issues
    fi
    
    # Check security settings
    local config
    config=$(jq . "$DOCKER_DAEMON_JSON" 2>/dev/null)
    
    # Check user namespace remapping
    if echo "$config" | jq -e '."userns-remap"' >/dev/null 2>&1; then
        log_info "✓ User namespace remapping is configured"
    else
        log_warn "⚠ User namespace remapping not configured"
        ((issues++))
    fi
    
    # Check no-new-privileges
    if echo "$config" | jq -e '."no-new-privileges"' | grep -q true; then
        log_info "✓ no-new-privileges is enabled"
    else
        log_warn "⚠ no-new-privileges is not enabled"
        ((issues++))
    fi
    
    # Check live restore
    if echo "$config" | jq -e '."live-restore"' | grep -q true; then
        log_info "✓ Live restore is enabled"
    else
        log_warn "⚠ Live restore is not enabled"
        ((issues++))
    fi
    
    # Check icc (inter-container communication)
    if echo "$config" | jq -e '.icc' | grep -q false; then
        log_info "✓ Inter-container communication is disabled"
    else
        log_warn "⚠ Inter-container communication is enabled"
        ((issues++))
    fi
    
    # Check userland proxy
    if echo "$config" | jq -e '."userland-proxy"' | grep -q false; then
        log_info "✓ Userland proxy is disabled"
    else
        log_warn "⚠ Userland proxy is enabled"
        ((issues++))
    fi
    
    # Check seccomp profile
    if echo "$config" | jq -e '."seccomp-profile"' >/dev/null 2>&1; then
        local seccomp_profile
        seccomp_profile=$(echo "$config" | jq -r '."seccomp-profile"')
        if [[ -f "$seccomp_profile" ]]; then
            log_info "✓ Custom seccomp profile is configured and exists"
        else
            log_error "Custom seccomp profile configured but file not found: $seccomp_profile"
            ((issues++))
        fi
    else
        log_warn "⚠ No custom seccomp profile configured"
        ((issues++))
    fi
    
    return $issues
}

# Check running containers security
check_container_security() {
    local issues=0
    local containers
    
    # Get list of running containers
    if ! containers=$(docker ps --format "{{.ID}} {{.Image}} {{.Names}}" 2>/dev/null); then
        log_error "Failed to list running containers"
        return 1
    fi
    
    if [[ -z "$containers" ]]; then
        log_info "No running containers found"
        return 0
    fi
    
    log_info "Checking security of running containers..."
    
    while IFS= read -r container_line; do
        if [[ -z "$container_line" ]]; then
            continue
        fi
        
        local container_id container_image container_name
        read -r container_id container_image container_name <<< "$container_line"
        
        log_info "Checking container: $container_name ($container_id)"
        
        # Check if container is running with --privileged
        if docker inspect "$container_id" --format '{{.HostConfig.Privileged}}' 2>/dev/null | grep -q true; then
            log_error "⚠ Container $container_name is running in privileged mode"
            ((issues++))
        fi
        
        # Check if container has excessive capabilities
        local caps
        caps=$(docker inspect "$container_id" --format '{{.HostConfig.CapAdd}}' 2>/dev/null || echo "[]")
        if [[ "$caps" != "[]" && "$caps" != "<no value>" ]]; then
            log_warn "⚠ Container $container_name has additional capabilities: $caps"
            ((issues++))
        fi
        
        # Check if container is running as root
        local user
        user=$(docker inspect "$container_id" --format '{{.Config.User}}' 2>/dev/null || echo "")
        if [[ -z "$user" || "$user" == "root" || "$user" == "0" ]]; then
            log_warn "⚠ Container $container_name is running as root user"
            ((issues++))
        fi
        
        # Check for host network mode
        local network_mode
        network_mode=$(docker inspect "$container_id" --format '{{.HostConfig.NetworkMode}}' 2>/dev/null || echo "")
        if [[ "$network_mode" == "host" ]]; then
            log_warn "⚠ Container $container_name is using host network mode"
            ((issues++))
        fi
        
        # Check for host PID mode
        local pid_mode
        pid_mode=$(docker inspect "$container_id" --format '{{.HostConfig.PidMode}}' 2>/dev/null || echo "")
        if [[ "$pid_mode" == "host" ]]; then
            log_warn "⚠ Container $container_name is using host PID mode"
            ((issues++))
        fi
        
        # Check for dangerous volume mounts
        local mounts
        mounts=$(docker inspect "$container_id" --format '{{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}' 2>/dev/null || echo "")
        if echo "$mounts" | grep -q "/:/"; then
            log_error "⚠ Container $container_name has root filesystem mounted"
            ((issues++))
        fi
        if echo "$mounts" | grep -q "/var/run/docker.sock:"; then
            log_error "⚠ Container $container_name has Docker socket mounted"
            ((issues++))
        fi
        if echo "$mounts" | grep -q "/proc:"; then
            log_warn "⚠ Container $container_name has /proc mounted"
            ((issues++))
        fi
        
    done <<< "$containers"
    
    return $issues
}

# Check Docker networks security
check_network_security() {
    local issues=0
    
    # Check if default bridge network is disabled
    local bridge_config
    if bridge_config=$(docker network inspect bridge --format '{{.Options}}' 2>/dev/null); then
        if echo "$bridge_config" | grep -q "com.docker.network.bridge.enable_icc:false"; then
            log_info "✓ Default bridge ICC is disabled"
        else
            log_warn "⚠ Default bridge ICC is not explicitly disabled"
            ((issues++))
        fi
    fi
    
    # Check for custom networks
    local custom_networks
    custom_networks=$(docker network ls --filter driver=bridge --format "{{.Name}}" | grep -v bridge | wc -l)
    if [[ $custom_networks -gt 0 ]]; then
        log_info "✓ Found $custom_networks custom bridge networks"
    else
        log_warn "⚠ No custom bridge networks found"
        ((issues++))
    fi
    
    return $issues
}

# Check AppArmor profiles
check_apparmor_profiles() {
    local issues=0
    
    if ! command -v apparmor_status >/dev/null 2>&1; then
        log_warn "AppArmor not available - skipping profile checks"
        return 0
    fi
    
    # Check if Docker profiles are loaded
    local docker_profiles
    docker_profiles=$(apparmor_status --enabled 2>/dev/null | grep -c docker || true)
    if [[ $docker_profiles -gt 0 ]]; then
        log_info "✓ Found $docker_profiles Docker AppArmor profiles"
    else
        log_warn "⚠ No Docker AppArmor profiles found"
        ((issues++))
    fi
    
    # Check specific profiles
    if apparmor_status --enabled 2>/dev/null | grep -q docker-hardened; then
        log_info "✓ docker-hardened profile is loaded"
    else
        log_warn "⚠ docker-hardened profile is not loaded"
        ((issues++))
    fi
    
    if apparmor_status --enabled 2>/dev/null | grep -q coolify-container; then
        log_info "✓ coolify-container profile is loaded"
    else
        log_warn "⚠ coolify-container profile is not loaded"
        ((issues++))
    fi
    
    return $issues
}

# Check for security vulnerabilities in images
check_image_vulnerabilities() {
    local issues=0
    
    # This is a basic check - in production you'd use tools like Trivy, Clair, etc.
    local images
    images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>" | head -10)
    
    log_info "Checking recent images for obvious security issues..."
    
    while IFS= read -r image; do
        if [[ -z "$image" ]]; then
            continue
        fi
        
        # Check if image is using latest tag (security anti-pattern)
        if echo "$image" | grep -q ":latest$"; then
            log_warn "⚠ Image $image uses 'latest' tag (consider pinning to specific version)"
            ((issues++))
        fi
        
        # Check for common base images with known issues
        if echo "$image" | grep -qE "(alpine:3\.[0-7]|ubuntu:1[46]\.|debian:[7-9])"; then
            log_warn "⚠ Image $image may be using outdated base image"
            ((issues++))
        fi
        
    done <<< "$images"
    
    return $issues
}

# Generate security report
generate_report() {
    local total_issues=$1
    
    log_info "=== Docker Security Monitor Report ==="
    log_info "Timestamp: $(date)"
    log_info "Total security issues found: $total_issues"
    
    if [[ $total_issues -eq 0 ]]; then
        log_info "✓ No security issues detected"
    elif [[ $total_issues -lt $ALERT_THRESHOLD_HIGH ]]; then
        log_warn "⚠ Low priority: $total_issues issues detected"
    elif [[ $total_issues -lt $ALERT_THRESHOLD_CRITICAL ]]; then
        log_warn "⚠ High priority: $total_issues issues detected"
    else
        log_error "🚨 Critical: $total_issues issues detected - immediate attention required"
    fi
    
    log_info "=== End Report ==="
}

# Main monitoring function
main() {
    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")"
    
    log_info "Starting Docker security monitoring..."
    
    local total_issues=0
    
    # Check Docker status
    if ! check_docker_status; then
        log_error "Docker is not running - cannot perform security checks"
        exit 1
    fi
    
    # Run security checks
    log_info "Checking Docker daemon configuration..."
    local daemon_issues
    daemon_issues=$(check_daemon_config)
    total_issues=$((total_issues + daemon_issues))
    
    log_info "Checking container security..."
    local container_issues
    container_issues=$(check_container_security)
    total_issues=$((total_issues + container_issues))
    
    log_info "Checking network security..."
    local network_issues
    network_issues=$(check_network_security)
    total_issues=$((total_issues + network_issues))
    
    log_info "Checking AppArmor profiles..."
    local apparmor_issues
    apparmor_issues=$(check_apparmor_profiles)
    total_issues=$((total_issues + apparmor_issues))
    
    log_info "Checking image vulnerabilities..."
    local image_issues
    image_issues=$(check_image_vulnerabilities)
    total_issues=$((total_issues + image_issues))
    
    # Generate report
    generate_report $total_issues
    
    # Exit with appropriate code
    if [[ $total_issues -ge $ALERT_THRESHOLD_CRITICAL ]]; then
        exit 2  # Critical issues
    elif [[ $total_issues -ge $ALERT_THRESHOLD_HIGH ]]; then
        exit 1  # High priority issues
    else
        exit 0  # No issues or low priority
    fi
}

# Run main function
main "$@"