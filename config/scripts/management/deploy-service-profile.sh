#!/bin/bash
# Service Profile Deployment Helper
# Usage: deploy-service-profile <service-name> <mode>

SERVICE="$1"
MODE="${2:-complain}"

if [[ -z "$SERVICE" ]]; then
    echo "Usage: $0 <service-name> [complain|enforce]"
    exit 1
fi

PROFILE_PATH="/etc/apparmor.d/usr.sbin.$SERVICE"

if [[ ! -f "$PROFILE_PATH" ]] && [[ ! -f "/etc/apparmor.d/usr.lib.*$SERVICE*" ]]; then
    echo "No AppArmor profile found for $SERVICE"
    echo "Available profiles:"
    find /etc/apparmor.d -name "*$SERVICE*" -type f | head -5
    exit 1
fi

# Set profile mode
case "$MODE" in
    "complain")
        aa-complain "$PROFILE_PATH" 2>/dev/null || aa-complain "/etc/apparmor.d/usr.lib.*$SERVICE*" 2>/dev/null
        echo "$SERVICE profile set to complain mode"
        ;;
    "enforce")
        echo "WARNING: Setting $SERVICE to enforce mode"
        read -p "Are you sure? Test in complain mode first (y/N): " confirm
        if [[ "$confirm" == "y" ]]; then
            aa-enforce "$PROFILE_PATH" 2>/dev/null || aa-enforce "/etc/apparmor.d/usr.lib.*$SERVICE*" 2>/dev/null
            echo "$SERVICE profile set to enforce mode"
        fi
        ;;
esac

# Show status
aa-status | grep -i "$SERVICE" || echo "Profile not active"