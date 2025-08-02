#!/bin/bash
# SSH Security Audit Script

echo "=== SSH Security Audit Report ==="
echo "Generated: $(date)"
echo ""

# Check SSH service status
echo "SSH Service Status:"
systemctl status ssh --no-pager -l

echo ""
echo "SSH Configuration Summary:"
echo "Port: $(grep -E '^Port ' /etc/ssh/sshd_config | awk '{print $2}')"
echo "PermitRootLogin: $(grep -E '^PermitRootLogin ' /etc/ssh/sshd_config | awk '{print $2}')"
echo "PasswordAuthentication: $(grep -E '^PasswordAuthentication ' /etc/ssh/sshd_config | awk '{print $2}')"

echo ""
echo "Recent SSH Login Attempts:"
grep "sshd" /var/log/auth.log | tail -10

echo ""
echo "fail2ban SSH Jail Status:"
if command -v fail2ban-client >/dev/null 2>&1; then
    fail2ban-client status sshd 2>/dev/null || echo "SSH jail not active"
fi

echo ""
echo "Active SSH Connections:"
ss -tuln | grep ":$(grep -E '^Port ' /etc/ssh/sshd_config | awk '{print $2}' || echo 22)"

echo ""
echo "=== End of SSH Audit Report ==="