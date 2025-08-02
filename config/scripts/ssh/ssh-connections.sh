#!/bin/bash
# SSH Connection Management Script

show_help() {
    echo "SSH Connection Management"
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  list      Show active SSH connections"
    echo "  masters   Show ControlMaster connections"
    echo "  clean     Clean up stale ControlMaster sockets"
    echo "  test      Test SSH configuration"
    echo "  help      Show this help"
}

list_connections() {
    echo "Active SSH connections:"
    ss -tuln | grep :22 || echo "No SSH connections found"
}

show_masters() {
    echo "ControlMaster sockets:"
    if [[ -d ~/.ssh/controlmasters ]]; then
        ls -la ~/.ssh/controlmasters/ || echo "No ControlMaster sockets found"
    else
        echo "ControlMaster directory not found"
    fi
}

clean_masters() {
    echo "Cleaning up stale ControlMaster sockets..."
    if [[ -d ~/.ssh/controlmasters ]]; then
        find ~/.ssh/controlmasters -type s -mtime +1 -delete
        echo "Cleanup complete"
    fi
}

test_config() {
    echo "Testing SSH configuration..."
    ssh -T -o ConnectTimeout=5 -o BatchMode=yes git@github.com 2>&1 | head -1 || echo "SSH test failed"
}

case "${1:-help}" in
    list)
        list_connections
        ;;
    masters)
        show_masters
        ;;
    clean)
        clean_masters
        ;;
    test)
        test_config
        ;;
    help|*)
        show_help
        ;;
esac