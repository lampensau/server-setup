#!/bin/bash
# MOTD Cache Warmer - Preload cache files to speed up login
# Usage: Run via cron every 30 minutes
# Crontab entry: */30 * * * * /usr/local/bin/motd-cache-warmer.sh >/dev/null 2>&1

# Logging setup
LOG_FILE="/var/log/motd-cache-warmer.log"
exec 1> >(logger -t motd-cache-warmer -p user.info)
exec 2> >(logger -t motd-cache-warmer -p user.err)

log_info() {
    local msg="$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || echo "$msg" >&2
}

log_error() {
    local msg="$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || echo "$msg" >&2
}

# Configuration
CACHE_DIR="${MOTD_CACHE_DIR:-/tmp/.motd-cache}"
CACHE_TTL_UPDATES=60    # 1 hour
CACHE_TTL_AUTOREMOVE=30 # 30 minutes

# Utility functions
command_exists() { command -v "$1" >/dev/null 2>&1; }

safe_cache_write() {
    local content="$1" file="$2"
    echo "$content" > "${file}.tmp" 2>/dev/null && mv "${file}.tmp" "$file" 2>/dev/null
}

check_cache_file() {
    local file="$1" ttl="$2"
    [ ! -f "$file" ] || [ -n "$(find "$file" -mmin +$ttl 2>/dev/null)" ]
}

# Initialize cache directory
if [ ! -d "$CACHE_DIR" ]; then
    mkdir -p "$CACHE_DIR" 2>/dev/null
    log_info "Created cache directory: $CACHE_DIR"
fi

log_info "Starting cache warming cycle"

# Warm APT updates cache
if command_exists apt-get; then
    APT_CACHE="$CACHE_DIR/apt-updates"
    if check_cache_file "$APT_CACHE" "$CACHE_TTL_UPDATES"; then
        if [ -f /var/lib/apt/periodic/update-success-stamp ]; then
            timeout 5 apt list --upgradable 2>/dev/null | grep "upgradable" > "${APT_CACHE}.tmp" 2>/dev/null || true
            [ -f "${APT_CACHE}.tmp" ] && mv "${APT_CACHE}.tmp" "$APT_CACHE"
        fi
    fi
    
    # Warm autoremove cache
    AUTOREMOVE_CACHE="$CACHE_DIR/apt-autoremove"
    if check_cache_file "$AUTOREMOVE_CACHE" "$CACHE_TTL_AUTOREMOVE"; then
        AUTOREMOVE=$(timeout 3 apt-get --dry-run autoremove 2>/dev/null | grep -c "^Remv" || echo "0")
        safe_cache_write "$AUTOREMOVE" "$AUTOREMOVE_CACHE"
    fi
fi

# Warm fail2ban cache
if command_exists fail2ban-client && systemctl is-active --quiet fail2ban 2>/dev/null; then
    F2B_CACHE="$CACHE_DIR/fail2ban-status"
    if check_cache_file "$F2B_CACHE" 5; then  # 5 min cache for fail2ban
        BANS=$(timeout 3 fail2ban-client banned 2>/dev/null | grep -c "^[0-9]" || echo "0")
        safe_cache_write "$BANS" "$F2B_CACHE"
    fi
fi

# Future: Warm restic cache when implemented
if command_exists restic && [ -f "/etc/restic/restic.conf" ]; then
    # BACKUP_CACHE="$CACHE_DIR/restic-status"
    # if check_cache_file "$BACKUP_CACHE" 60; then
    #     LAST_BACKUP=$(timeout 10 restic snapshots --json --last 2>/dev/null | jq -r '.[0].time' 2>/dev/null | cut -d'T' -f1)
    #     safe_cache_write "$LAST_BACKUP" "$BACKUP_CACHE"
    # fi
    true
fi

log_info "Cache warming cycle completed"