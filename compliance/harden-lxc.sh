#!/bin/bash
set -euo pipefail

TARGET_CTS="102 103 105 106 108 109 111"

for CT in $TARGET_CTS; do
  echo "=============================================="
  echo "Hardening CT${CT}..."
  echo "=============================================="

  # 1. Remove deprecated Sonarr repo (if present)
  pct exec $CT -- rm -f /etc/apt/sources.list.d/sonarr.list

  # 2. Install unattended-upgrades
  pct exec $CT -- bash -c "apt update && apt install -y unattended-upgrades"
  
  # 3. Stop, disable, mask postfix if the unit exists
  pct exec $CT -- bash -c "if systemctl is-active --quiet postfix@-.service; then systemctl stop postfix@-.service; fi"
  pct exec $CT -- bash -c "if systemctl is-enabled --quiet postfix@-.service 2>/dev/null; then systemctl disable postfix@-.service; fi"
  pct exec $CT -- bash -c "systemctl mask postfix@-.service 2>/dev/null || true"

  # 4. Kernel parameters via sysctl.d
  pct exec $CT -- bash -c 'cat > /etc/sysctl.d/99-cis-hardening.conf << EOF
# CIS 3.1.2
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0

# CIS 3.1.5
net.ipv4.conf.all.secure_redirects=0
net.ipv4.conf.default.secure_redirects=0

# CIS 3.1.6
net.ipv4.conf.all.log_martians=1
net.ipv4.conf.default.log_martians=1
EOF'
  pct exec $CT -- sysctl -p /etc/sysctl.d/99-cis-hardening.conf

  # 5. SSH hardening via drop-in
  pct exec $CT -- mkdir -p /etc/ssh/sshd_config.d
  pct exec $CT -- bash -c 'cat > /etc/ssh/sshd_config.d/99-cis-hardening.conf << EOF
PasswordAuthentication no
MaxAuthTries 4
PubkeyAuthentication yes
PermitRootLogin prohibit-password
EOF'
  pct exec $CT -- systemctl restart sshd

  # 6. /etc/crontab permissions
  pct exec $CT -- chmod 600 /etc/crontab

  # 7. umask and TMOUT in /etc/profile
  pct exec $CT -- bash -c 'grep -q "umask 027" /etc/profile || echo "umask 027" >> /etc/profile'
  pct exec $CT -- bash -c 'grep -q "TMOUT=600" /etc/profile || echo "TMOUT=600; readonly TMOUT; export TMOUT" >> /etc/profile'

  echo "CT${CT} done."
done

echo "All containers hardened."
