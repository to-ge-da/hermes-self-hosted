#!/bin/bash
#
# hardening.sh — Server security hardening
# Run AFTER bootstrap.sh as root on a fresh Debian Server.
#
# Covers:
#   - SSH hardening
#   - Firewall (UFW)
#   - Fail2Ban
#   - Kernel hardening (sysctl)
#   - Auditd
#   - AIDE (integrity monitoring)
#   - rkhunter (rootkit detection)
#   - AppArmor
#   - File permissions
#   - Shared memory hardening
#   - Disable unnecessary services
#   - Unattended security upgrades
#
# Usage:
#   sudo ./hardening.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ──────────────────────
# Helpers
# ──────────────────────
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
NC=$'\033[0m'

# shellcheck source=lib/banner.sh
source "$SCRIPT_DIR/lib/banner.sh"

log()  { echo -e "${GREEN}[HARDENING]${NC} $1"; }
warn() { echo -e "${YELLOW}[HARDENING]${NC} $1"; }
err()  { echo -e "${RED}[HARDENING]${NC} $1" >&2; exit 1; }

usage() {
    cat <<EOF
Usage: $0 [options]

Hardening script for Hermes Agent on Debian servers.
Run this AFTER bootstrap.sh on a fresh Debian install.

Options:
  --force             Continue even if the admin user has no SSH keys
                      (you can lock yourself out of SSH)
  -h, --help          Show this help message

Must be run as root (sudo).

Examples:
  sudo ./hardening.sh
EOF
    exit 0
}

# ──────────────────────
# Parse arguments
# ──────────────────────
FORCE=false

print_hermes_banner "hardening"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)
            FORCE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            err "Unknown option: $1. Use --help for usage."
            ;;
    esac
done

# ──────────────────────
# Pre-flight
# ──────────────────────
if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root (use sudo)."
fi

# ──────────────────────
# Fix /etc/hosts (avoid sudo: unable to resolve host warnings)
# ──────────────────────
CURRENT_HOSTNAME=$(hostname)
if ! grep -qi "$CURRENT_HOSTNAME" /etc/hosts 2>/dev/null; then
    log "Fixing /etc/hosts: adding $CURRENT_HOSTNAME"
    if grep -q '^127\.0\.1\.1' /etc/hosts; then
        sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$CURRENT_HOSTNAME/" /etc/hosts
    elif grep -q '^127\.0\.0\.1' /etc/hosts; then
        # Add after localhost line
        sed -i "/^127\.0\.0\.1.*localhost/a 127.0.1.1\t$CURRENT_HOSTNAME" /etc/hosts
    else
        echo "127.0.1.1\t$CURRENT_HOSTNAME" >> /etc/hosts
    fi
    log "/etc/hosts updated — sudo hostname warnings resolved."
fi

# ──────────────────────
# 1. SSH Hardening
# ──────────────────────
log "Hardening SSH..."

SSH_CONFIG_DIR="/etc/ssh/sshd_config.d"
SSH_HARDENED="$SSH_CONFIG_DIR/99-hardened.conf"

if [[ ! -d "$SSH_CONFIG_DIR" ]]; then
    mkdir -p "$SSH_CONFIG_DIR"
fi

# ──────────────────────
# Detect users with SSH keys for AllowUsers
# ──────────────────────
SSH_USERS="hermes"
for keyfile in /home/*/.ssh/authorized_keys; do
    if [[ -s "$keyfile" ]]; then
        username=$(echo "$keyfile" | cut -d/ -f3)
        if [[ "$username" != "hermes" ]]; then
            SSH_USERS="$SSH_USERS $username"
        fi
    fi
done

if [[ "$SSH_USERS" == "hermes" ]]; then
    warn "No SSH keys found for any user other than hermes."
    if [[ "$FORCE" != true ]]; then
        err "Refusing to disable password auth with AllowUsers=hermes only. Add the admin SSH key, or pass --force (you may lock yourself out)."
    fi
    warn "Continuing because --force was set. AllowUsers will only include 'hermes'."
fi

log "AllowUsers: $SSH_USERS"

cat > "$SSH_HARDENED" << EOF
# ├─────────────────
# │ SSH hardening — applied on top of the default config
# │ Configuring via drop-in preserves updates to sshd_config
# ├─────────────────

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
AllowUsers $SSH_USERS
EOF

chmod 600 "$SSH_HARDENED"

sshd -t || err "SSH configuration test failed. Fix errors before continuing."
systemctl restart sshd
log "SSH hardened. Config written to $SSH_HARDENED"

# ──────────────────────
# 2. Firewall (UFW)
# ──────────────────────
log "Configuring firewall (UFW)..."

apt install -y ufw

ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
# Do not `ufw allow icmp` — UFW treats that as an application profile
# name and errors: "Could not find a profile matching 'icmp'".
# Debian's /etc/ufw/before.rules already ACCEPTs echo-request (ping).
ufw --force enable

log "Firewall enabled. SSH (22/tcp) allowed inbound."

# ──────────────────────
# 3. Fail2Ban
# ──────────────────────
log "Configuring Fail2Ban..."

apt install -y fail2ban

cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime   = 3600
findtime  = 600
maxretry  = 3
banaction = iptables-multiport

[sshd]
enabled   = true
port      = ssh
filter    = sshd
logpath   = /var/log/auth.log
maxretry  = 3
bantime   = 3600
EOF

systemctl enable fail2ban
systemctl restart fail2ban
log "Fail2Ban configured and started."

# ──────────────────────
# 4. Unattended Security Upgrades
# ──────────────────────
log "Configuring unattended-upgrades..."

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

log "Unattended security upgrades configured."

# ──────────────────────
# 5. Kernel Hardening (sysctl)
# ──────────────────────
log "Applying kernel hardening..."

cat > /etc/sysctl.d/99-hardening.conf << 'EOF'
# IP spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Do not send ICMP redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# SYN flood protection
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

# Full ASLR
kernel.randomize_va_space = 2

# Disable core dumps for SUID programs
fs.suid_dumpable = 0

# Restrict unprivileged BPF
kernel.unprivileged_bpf_disabled = 1

# Protect hardlinks and symlinks
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
EOF

sysctl --system
log "Kernel hardening applied."

# ──────────────────────
# 6. Resource Limits
# ──────────────────────
log "Setting resource limits..."

cat > /etc/security/limits.d/99-hardening.conf << 'EOF'
# Disable core dumps for all users
root hard core 0
*    hard core 0
EOF

log "Resource limits set."

# ──────────────────────
# 7. AppArmor
# ──────────────────────
log "Enabling AppArmor..."

if systemctl list-unit-files apparmor.service &>/dev/null; then
    apt install -y apparmor apparmor-utils
    aa-enforce /etc/apparmor.d/* 2>/dev/null || true
    log "AppArmor enforced."
else
    warn "AppArmor not available in this environment. Skipping."
fi

# ──────────────────────
# 8. Auditd
# ──────────────────────
log "Configuring auditd..."

apt install -y auditd

systemctl enable auditd
systemctl start auditd 2>/dev/null || warn "auditd already running or started."

cat > /etc/audit/rules.d/audit.rules << 'EOF'
# Clear existing rules
-D

# Buffer
-b 8192

# Monitor auth events
-w /var/log/auth.log -p wa -k auth
-w /etc/ssh/sshd_config -p wa -k ssh_config
-w /etc/ssh/sshd_config.d/ -p wa -k ssh_config

# Monitor user/group changes
-w /etc/passwd -p wa -k passwd_changes
-w /etc/group -p wa -k group_changes
-w /etc/shadow -p wa -k shadow_changes

# Monitor sudoers
-w /etc/sudoers -p wa -k sudoers_changes

# Monitor cron
-w /etc/crontab -p wa -k cron_changes

# Monitor time changes
-a always,exit -F arch=b64 -S settimeofday -k time_change
-a always,exit -F arch=b64 -S clock_settime -k time_change

# Monitor kernel module loading
-a always,exit -F arch=b64 -S init_module -S finit_module -k module_load
EOF

augenrules --load 2>/dev/null || systemctl restart auditd
log "Auditd configured."

# ──────────────────────
# 9. AIDE — File Integrity Monitoring
# ──────────────────────
log "Initializing AIDE..."

apt install -y aide

# aideinit can take a while on slow systems; suppress warnings
aideinit 2>/dev/null || warn "AIDE init had warnings (non-critical)."
if [[ -f /var/lib/aide/aide.db.new ]]; then
    cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
    log "AIDE database initialized."
else
    warn "AIDE database file not found. Continuing without integrity baseline."
fi

# ──────────────────────
# 10. rkhunter — Rootkit Detection
# ──────────────────────
log "Setting up rkhunter..."

apt install -y rkhunter

rkhunter --update 2>/dev/null || warn "rkhunter update had non-critical warnings."
rkhunter --propupd 2>/dev/null || warn "rkhunter propupd had non-critical warnings."
log "rkhunter configured."

# ──────────────────────
# 11. File Permissions
# ──────────────────────
log "Hardening file permissions..."

chmod 700 /root
chmod 600 /etc/shadow
chmod 600 /etc/gshadow

# Restrict crontab to root
touch /etc/cron.allow
chmod 600 /etc/cron.allow
echo "root" > /etc/cron.allow
touch /etc/cron.deny
chmod 600 /etc/cron.deny

log "File permissions tightened."

# ──────────────────────
# 12. Shared Memory Hardening
# ──────────────────────
log "Hardening /dev/shm..."

mount -o remount,noexec,nosuid,nodev /dev/shm 2>/dev/null || true

if ! grep -q '/dev/shm' /etc/fstab; then
    echo 'tmpfs /dev/shm tmpfs defaults,noexec,nosuid,nodev 0 0' >> /etc/fstab
fi

log "/dev/shm hardened."

# ──────────────────────
# 13. Disable Unnecessary Services
# ──────────────────────
log "Disabling unnecessary services..."

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
        log "Disabled: $svc"
    fi
done

# ──────────────────────
# Done
# ──────────────────────
echo ""
echo "=================================="
echo "  HARDENING COMPLETE"
echo "=================================="
echo ""
echo "Applied:"
echo "  ✓ SSH hardened (keys only, no root)"
echo "  ✓ UFW enabled (SSH only inbound)"
echo "  ✓ Fail2Ban (SSH brute-force protection)"
echo "  ✓ Unattended security upgrades"
echo "  ✓ Kernel hardening (sysctl)"
echo "  ✓ Auditd (system event monitoring)"
echo "  ✓ AIDE (file integrity)"
echo "  ✓ rkhunter (rootkit detection)"
echo "  ✓ AppArmor enforced"
echo "  ✓ File permissions hardened"
echo "  ✓ /dev/shm secured (noexec,nosuid,nodev)"
echo "  ✓ Unnecessary services disabled"
echo ""
echo "Reboot to apply all changes:"
echo "  sudo reboot"
echo "=================================="
