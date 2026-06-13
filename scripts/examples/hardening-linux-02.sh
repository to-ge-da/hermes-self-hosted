#!/bin/bash

set -euo pipefail

ROOT_CHECK() {
    if [[ $EUID -ne 0 ]]; then
        echo "Run this script as root." >&2
        exit 1
    fi
}

LOG() {
    echo "[HARDENING] $1"
}

ROOT_CHECK

# -------------------------------------------------------
# 1. System Update
# -------------------------------------------------------
LOG "Updating system..."
apt update && apt upgrade -y
apt dist-upgrade -y
apt autoremove -y

# -------------------------------------------------------
# 2. User Setup
# -------------------------------------------------------
LOG "Creating hermes user..."
if ! id "hermes" &>/dev/null; then
    adduser --disabled-password --gecos "Hermes Agent" hermes
    passwd -l hermes
    mkdir -p /home/hermes/.ssh
    chmod 700 /home/hermes/.ssh
    chown hermes:hermes /home/hermes/.ssh
    touch /home/hermes/.ssh/authorized_keys
    chmod 600 /home/hermes/.ssh/authorized_keys
    chown hermes:hermes /home/hermes/.ssh/authorized_keys
    LOG "User 'hermes' created (key-only auth, no password)."
else
    LOG "User 'hermes' already exists, skipping."
fi

LOG "Locking root account..."
passwd -l root

# -------------------------------------------------------
# 3. SSH Hardening
# -------------------------------------------------------
LOG "Hardening SSH..."

SSH_HARDENED="/etc/ssh/sshd_config.d/hardened.conf"

if [[ ! -d /etc/ssh/sshd_config.d ]]; then
    mkdir -p /etc/ssh/sshd_config.d
fi

cat > "$SSH_HARDENED" << 'EOF'
Port 22
PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
PubkeyAuthentication yes
MaxAuthTries 3
LoginGraceTime 20
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
AllowUsers admin hermes
EOF

LOG "SSH hardened config written to $SSH_HARDENED"

systemctl restart sshd

# -------------------------------------------------------
# 4. Firewall
# -------------------------------------------------------
LOG "Configuring firewall (ufw)..."
apt install -y ufw

ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw --force enable

LOG "Firewall enabled. SSH (22/tcp) allowed."

# -------------------------------------------------------
# 5. Fail2Ban
# -------------------------------------------------------
LOG "Configuring Fail2Ban..."
apt install -y fail2ban

cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
banaction = iptables-multiport

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF

systemctl enable fail2ban
systemctl restart fail2ban

LOG "Fail2Ban configured and started."

# -------------------------------------------------------
# 6. Unattended Security Upgrades
# -------------------------------------------------------
LOG "Configuring unattended-upgrades..."
apt install -y unattended-upgrades apt-listchanges

cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
EOF

LOG "Unattended security upgrades configured."

# -------------------------------------------------------
# 7. Kernel Hardening (sysctl)
# -------------------------------------------------------
LOG "Applying kernel hardening (sysctl)..."

cat > /etc/sysctl.d/99-hardening.conf << 'EOF'
# IP spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Disable ICMP redirects (prevent MITM)
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Do not send ICMP redirects (not a router)
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Enable SYN cookies (prevent SYN flood)
net.ipv4.tcp_syncookies = 1

# Disable source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Disable sysrq
kernel.sysrq = 0

# Restrict dmesg to root
kernel.dmesg_restrict = 1

# Restrict kernel pointer access
kernel.kptr_restrict = 2

# Enable ASLR
kernel.randomize_va_space = 2

# Disable core dumps for SUID programs
fs.suid_dumpable = 0

# Restrict unprivileged use of BPF
kernel.unprivileged_bpf_disabled = 1

# Protect hardlinks and symlinks
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
EOF

sysctl --system

LOG "Kernel hardening applied."

# -------------------------------------------------------
# 8. Resource Limits
# -------------------------------------------------------
LOG "Setting resource limits..."

cat > /etc/security/limits.d/99-hardening.conf << 'EOF'
# Disable core dumps
root hard core 0
* hard core 0
EOF

LOG "Resource limits set."

# -------------------------------------------------------
# 9. AppArmor
# -------------------------------------------------------
LOG "Enabling AppArmor..."
apt install -y apparmor apparmor-utils

aa-enforce /etc/apparmor.d/* 2>/dev/null || true

LOG "AppArmor enabled."

# -------------------------------------------------------
# 10. Audit Framework
# -------------------------------------------------------
LOG "Configuring auditd..."
apt install -y auditd

systemctl enable auditd
systemctl start auditd

cat > /etc/audit/rules.d/audit.rules << 'EOF'
# Delete existing rules
-D

# Buffer size
-b 8192

# Monitor authentication events
-w /var/log/auth.log -p wa -k auth
-w /etc/ssh/sshd_config -p wa -k ssh_config
-w /etc/ssh/sshd_config.d/ -p wa -k ssh_config

# Monitor user/group changes
-w /etc/passwd -p wa -k passwd_changes
-w /etc/group -p wa -k group_changes
-w /etc/shadow -p wa -k shadow_changes

# Monitor sudoers changes
-w /etc/sudoers -p wa -k sudoers_changes

# Monitor cron changes
-w /etc/crontab -p wa -k cron_changes

# Monitor system time changes
-a always,exit -F arch=b64 -S settimeofday -k time_change
-a always,exit -F arch=b64 -S clock_settime -k time_change

# Monitor kernel module loading
-a always,exit -F arch=b64 -S init_module -S finit_module -k module_load
EOF

augenrules --load

LOG "Auditd configured and rules loaded."

# -------------------------------------------------------
# 11. Integrity Monitoring
# -------------------------------------------------------
LOG "Setting up AIDE..."
apt install -y aide

aideinit
cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db

LOG "AIDE database initialized."

# -------------------------------------------------------
# 12. Rootkit Detection
# -------------------------------------------------------
LOG "Setting up rkhunter..."
apt install -y rkhunter

rkhunter --update
rkhunter --propupd

LOG "rkhunter configured."

# -------------------------------------------------------
# 13. Log Monitoring
# -------------------------------------------------------
LOG "Setting up logwatch..."
apt install -y logwatch

LOG "logwatch installed (review /etc/logwatch/ for customization)."

# -------------------------------------------------------
# 14. Disable Unnecessary Services
# -------------------------------------------------------
LOG "Disabling unnecessary services..."

DISABLE_SERVICES=(
    avahi-daemon
    cups
    nfs-server
    rpcbind
    bluetooth
)

for svc in "${DISABLE_SERVICES[@]}"; do
    if systemctl list-unit-files "${svc}.service" &>/dev/null; then
        systemctl stop "$svc" 2>/dev/null || true
        systemctl disable "$svc" 2>/dev/null || true
        LOG "Disabled: $svc"
    fi
done

# -------------------------------------------------------
# 15. File Permissions
# -------------------------------------------------------
LOG "Setting restrictive file permissions..."

chmod 700 /root
chmod 600 /etc/shadow
chmod 600 /etc/gshadow
chmod 600 /etc/sssd/sssd.conf 2>/dev/null || true

# Restrict crontab to root
touch /etc/cron.allow
chmod 600 /etc/cron.allow
echo "root" > /etc/cron.allow
touch /etc/cron.deny
chmod 600 /etc/cron.deny

LOG "File permissions hardened."

# -------------------------------------------------------
# 16. Shared Memory Hardening
# -------------------------------------------------------
LOG "Hardening /dev/shm..."

mount -o remount,noexec,nosuid,nodev /dev/shm 2>/dev/null || true

grep -q '/dev/shm' /etc/fstab || echo 'tmpfs /dev/shm tmpfs defaults,noexec,nosuid,nodev 0 0' >> /etc/fstab

LOG "/dev/shm hardened (noexec,nosuid,nodev)."

# -------------------------------------------------------
# Done
# -------------------------------------------------------
echo ""
echo "=========================================="
echo "  HARDENING COMPLETE"
echo "=========================================="
echo ""
echo "Before rebooting, make sure you have:"
echo "  1. Copied your SSH public key to /home/hermes/.ssh/authorized_keys"
echo "  2. Copied your SSH public key to /home/admin/.ssh/authorized_keys"
echo "  3. Tested SSH key login BEFORE disconnecting"
echo ""
echo "To add your SSH key from another machine:"
echo "  ssh-copy-id admin@<server-ip>"
echo "  ssh-copy-id hermes@<server-ip>"
echo ""
echo "Reboot to apply all changes."
echo "=========================================="
