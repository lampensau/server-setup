#!/bin/bash
# AppArmor monitoring script

echo "=== AppArmor Status ==="
sudo aa-status | head -10

echo ""
echo "=== Recent AppArmor Violations (last 24 hours) ==="
journalctl --since "24 hours ago" | grep -i apparmor | grep -i denied | tail -10

echo ""
echo "=== Profile Status Summary ==="
sudo aa-status | grep -E "(complain|enforce)" | sort