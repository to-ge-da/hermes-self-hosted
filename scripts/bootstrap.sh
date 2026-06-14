#!/bin/bash
#
# bootstrap.sh — Initial system setup: creates hermes user, base configuration
# Run as root on a fresh Debian Server installation.
#
# Pre-condition: the admin user already exists (created during Debian OS
# installation). This script does NOT create the admin user — only hermes.
#
# Usage:
#   chmod +x bootstrap.sh
#   sudo ./bootstrap.sh

set -euo pipefail

# ──────────────────────
# Helpers
# ──────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log()  { echo -e "${GREEN}[BOOTSTRAP]${NC} $1"; }
warn() { echo -e "${YELLOW}[BOOTSTRAP]${NC} $1"; }
err()  { echo -e "${RED}[BOOTSTRAP]${NC} $1" >&2; exit 1; }

# ──────────────────────
# Pre-flight
# ──────────────────────
if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root."
fi

# ──────────────────────
# 1. System update
# ──────────────────────
log "Updating system packages..."
apt update && apt upgrade -y
apt autoremove -y

# ──────────────────────
# 2. Essential packages
# ──────────────────────
log "Installing essential packages..."
apt install -y \
    sudo \
    openssh-server \
    curl \
    wget \
    git \
    vim \
    ufw \
    unattended-upgrades \
    apt-listchanges \
    tree \
    nmap

# ──────────────────────
# 3. Hostname
# ──────────────────────
CURRENT_HOSTNAME=$(hostname)
read -rp "Enter hostname [${CURRENT_HOSTNAME}]: " NEW_HOSTNAME
NEW_HOSTNAME=${NEW_HOSTNAME:-$CURRENT_HOSTNAME}

if [[ "$NEW_HOSTNAME" != "$CURRENT_HOSTNAME" ]]; then
    hostnamectl set-hostname "$NEW_HOSTNAME"
    log "Hostname set to: $NEW_HOSTNAME"
else
    log "Hostname unchanged: $CURRENT_HOSTNAME"
fi

# ──────────────────────
# 4. Timezone
# ──────────────────────
log "Configuring timezone..."
dpkg-reconfigure tzdata || true
log "Timezone set."

# ──────────────────────
# 5. Locale
# ──────────────────────
log "Configuring locale..."
if ! locale -a | grep -q 'en_US.utf8'; then
    locale-gen en_US.UTF-8
    update-locale LANG=en_US.UTF-8
    log "Locale set to en_US.UTF-8"
else
    log "Locale en_US.UTF-8 already available."
fi

# ──────────────────────
# 6. Current user (the one running the script via sudo)
# ──────────────────────

# $SUDO_USER is set when the script is invoked with sudo.
# On a fresh Debian install this is the user created during OS installation,
# who already has sudo privileges.
if [[ -n "${SUDO_USER:-}" ]]; then
    ADMIN_USER="$SUDO_USER"
else
    ADMIN_USER="${USER:-$(logname 2>/dev/null || echo 'root')}"
fi

if [[ "$ADMIN_USER" == "root" ]]; then
    err "This script must be run with sudo from a non-root user, not directly as root."
fi

log "Detected admin user: $ADMIN_USER"

# ──────────────────────
# 7. Log current user
# ──────────────────────
# The admin user already exists — created during Debian installation.
# This script does not create or configure the admin user.
log "Admin user: $ADMIN_USER (pre-existing from Debian installation)"

# ──────────────────────
# 8. Hermes agent user
# ──────────────────────
log "Creating hermes user..."

HERMES_USER="hermes"

if id "$HERMES_USER" &>/dev/null; then
    warn "User '$HERMES_USER' already exists, skipping creation."
else
    adduser --disabled-password --gecos "Hermes Agent" "$HERMES_USER"
    passwd -l "$HERMES_USER"
    log "User '$HERMES_USER' created (key-only auth, no password, no sudo)."
fi

# ──────────────────────
# 9. Hermes SSH key
# ──────────────────────
log "Setting up SSH for $HERMES_USER..."

mkdir -p "/home/$HERMES_USER/.ssh"
chmod 700 "/home/$HERMES_USER/.ssh"

read -rp "Paste the SSH public key for $HERMES_USER: " HERMES_SSH_KEY

if [[ -n "$HERMES_SSH_KEY" ]]; then
    echo "$HERMES_SSH_KEY" > "/home/$HERMES_USER/.ssh/authorized_keys"
    chmod 600 "/home/$HERMES_USER/.ssh/authorized_keys"
    chown -R "$HERMES_USER:$HERMES_USER" "/home/$HERMES_USER/.ssh"
    log "SSH key added for $HERMES_USER."
else
    warn "No SSH key provided for $HERMES_USER. You will need to add one manually."
    touch "/home/$HERMES_USER/.ssh/authorized_keys"
    chmod 600 "/home/$HERMES_USER/.ssh/authorized_keys"
    chown -R "$HERMES_USER:$HERMES_USER" "/home/$HERMES_USER/.ssh"
fi

# ──────────────────────
# 10. SSH directory for sshd_config.d
# ──────────────────────
if [[ ! -d /etc/ssh/sshd_config.d ]]; then
    mkdir -p /etc/ssh/sshd_config.d
    log "Created /etc/ssh/sshd_config.d"
fi

# ──────────────────────
# 11. Lock root account
# ──────────────────────
log "Locking root account..."
passwd -l root
log "Root account locked."

# ──────────────────────
# Done
# ──────────────────────
echo ""
echo "=================================="
echo "  BOOTSTRAP COMPLETE"
echo "=================================="
echo ""
echo "Summary:"
echo "  Hostname : $NEW_HOSTNAME"
echo "  Admin    : $ADMIN_USER (pre-existing, sudo)"
echo "  Agent    : $HERMES_USER (no sudo, key-only)"
echo ""
echo "Next steps:"
echo "  1. Verify SSH access for both users:"
echo "     ssh $ADMIN_USER@<server-ip>"
echo "     ssh $HERMES_USER@<server-ip>"
echo ""
echo "  2. Run hardening.sh for security configuration"
echo ""
echo "=================================="
