#!/bin/bash
#
# bootstrap.sh — Initial system setup: creates hermes user, base configuration
# Run as root on a fresh Debian Server installation.
#
# Usage:
#   sudo ./bootstrap.sh                      # interactive mode
#   sudo ./bootstrap.sh --hostname myhost     # non-interactive hostname
#   sudo ./bootstrap.sh --timezone UTC        # non-interactive timezone
#   sudo ./bootstrap.sh --ssh-key "$(cat ~/.ssh/id_ed25519.pub)"
#   sudo ./bootstrap.sh --hostname myhost --timezone America/Sao_Paulo --ssh-key "ssh-ed25519 AAA..."
#
# Pre-condition: the admin user already exists (created during Debian OS
# installation). This script does NOT create the admin user — only hermes.
#

set -euo pipefail
SECONDS=0

# ──────────────────────
# Defaults
# ──────────────────────
DEFAULT_TIMEZONE="UTC"
SCRIPT_VERSION="1.0.0"

# ──────────────────────
# Helpers
# ──────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

show_banner() {
    local term_width
    term_width=$(tput cols 2>/dev/null || echo 0)
    local width=50
    if [[ $term_width -lt $width ]] || [[ $term_width -gt 200 ]]; then
        width=$term_width
    fi
    local inner=$((width - 4))
    local half=$((inner / 2))
    local pad_total=$((half - 12))
    local pad1=$((pad_total > 0 ? pad_total : 0))

    printf '\n'
    printf '%s╔%s╗\n' "$GREEN" "$(printf '═%.0s' $(seq 1 $inner))"
    printf '%s║%s║\n' "$GREEN" "$(printf ' %.0s' $(seq 1 $inner))"
    printf '%s║%shermes-self-hosted%s║\n' "$GREEN" "$(printf ' %.0s' $(seq 1 $pad1))" "$(printf ' %.0s' $(seq 1 $pad1))"
    printf '%s║%sBootstrap Script v%s%s%s║\n' "$GREEN" "$(printf ' %.0s' $(seq 1 $pad1))" "$CYAN" "$SCRIPT_VERSION" "$(printf ' %.0s' $(seq 1 $((inner - pad1 * 2 - 20))))"
    printf '%s║%s║\n' "$GREEN" "$(printf ' %.0s' $(seq 1 $inner))"
    printf '%s╚%s╝\n' "$GREEN" "$(printf '═%.0s' $(seq 1 $inner))"
    printf '\n'
}

log()  { echo -e "${GREEN}[BOOTSTRAP]${NC} $1"; }
warn() { echo -e "${YELLOW}[BOOTSTRAP]${NC} $1"; }
err()  { echo -e "${RED}[BOOTSTRAP]${NC} $1" >&2; exit 1; }

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  --hostname NAME     Set hostname (non-interactive)
  --timezone ZONE     Set timezone (non-interactive, default: UTC)
  --ssh-key KEY       SSH public key for hermes user (run interactively if omitted)
  -h, --help          Show this help message

Examples:
  sudo ./bootstrap.sh --hostname hermes-server --timezone America/Sao_Paulo
  sudo ./bootstrap.sh --ssh-key "ssh-ed25519 AAAAC3..."
EOF
    exit 0
}

# ──────────────────────
# Parse arguments
# ──────────────────────
HOSTNAME_ARG=""
TIMEZONE_ARG=""
SSH_KEY_ARG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --hostname)
            HOSTNAME_ARG="$2"
            shift 2
            ;;
        --hostname=*)
            HOSTNAME_ARG="${1#*=}"
            shift
            ;;
        --timezone)
            TIMEZONE_ARG="$2"
            shift 2
            ;;
        --timezone=*)
            TIMEZONE_ARG="${1#*=}"
            shift
            ;;
        --ssh-key)
            SSH_KEY_ARG="$2"
            shift 2
            ;;
        --ssh-key=*)
            SSH_KEY_ARG="${1#*=}"
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

show_banner

# ──────────────────────
# 1. Fix /etc/hosts (avoid sudo: unable to resolve host)
# ──────────────────────
# Common issue on fresh VMs: the hostname is not in /etc/hosts,
# causing sudo to emit a warning on every invocation.
CURRENT_HOSTNAME=$(hostname)
if ! grep -qi "$CURRENT_HOSTNAME" /etc/hosts 2>/dev/null; then
    log "Fixing /etc/hosts: adding $CURRENT_HOSTNAME"
    if grep -q '^127\.0\.1\.1' /etc/hosts; then
        # Replace the line that usually holds the hostname
        sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$CURRENT_HOSTNAME/" /etc/hosts
    else
        printf '127.0.1.1\t%s\n' "$CURRENT_HOSTNAME" >> /etc/hosts
    fi
    log "/etc/hosts updated — sudo hostname warnings will be resolved."
fi

# ──────────────────────
# 2. System update
# ──────────────────────
log "Updating system packages..."
apt update && apt upgrade -y
apt autoremove -y

# ──────────────────────
# 3. Essential packages
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
# 4. Hostname
# ──────────────────────
if [[ -n "$HOSTNAME_ARG" ]]; then
    log "Setting hostname (non-interactive): $HOSTNAME_ARG"
    hostnamectl set-hostname "$HOSTNAME_ARG"
    # Re-run /etc/hosts fix with the new hostname
    CURRENT_HOSTNAME="$HOSTNAME_ARG"
    if grep -q '^127\.0\.1\.1' /etc/hosts; then
        sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$CURRENT_HOSTNAME/" /etc/hosts
    else
        printf '127.0.1.1\t%s\n' "$CURRENT_HOSTNAME" >> /etc/hosts
    fi
    NEW_HOSTNAME="$HOSTNAME_ARG"
elif [[ -t 0 ]]; then
    # Interactive mode — only prompt if stdin is a terminal
    CURRENT_HOSTNAME=$(hostname)
    read -rp "Enter hostname [${CURRENT_HOSTNAME}]: " NEW_HOSTNAME
    NEW_HOSTNAME=${NEW_HOSTNAME:-$CURRENT_HOSTNAME}
    if [[ "$NEW_HOSTNAME" != "$CURRENT_HOSTNAME" ]]; then
        hostnamectl set-hostname "$NEW_HOSTNAME"
        log "Hostname set to: $NEW_HOSTNAME"
    else
        log "Hostname unchanged: $CURRENT_HOSTNAME"
    fi
else
    log "Non-interactive mode, hostname unchanged: $(hostname)"
    NEW_HOSTNAME="$(hostname)"
fi

# ──────────────────────
# 5. Timezone (non-interactive)
# ──────────────────────
TZ="${TIMEZONE_ARG:-$DEFAULT_TIMEZONE}"
log "Setting timezone: $TZ"
export DEBIAN_FRONTEND=noninteractive
timedatectl set-timezone "$TZ" 2>/dev/null || {
    # Fallback for systems without timedatectl
    ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime
    echo "$TZ" > /etc/timezone
}
log "Timezone set to $TZ (non-interactive)."

# ──────────────────────
# 6. Locale
# ──────────────────────
log "Configuring locale..."
if ! locale -a 2>/dev/null | grep -qi 'en_US.utf8'; then
    locale-gen en_US.UTF-8
    update-locale LANG=en_US.UTF-8
    log "Locale set to en_US.UTF-8"
else
    log "Locale en_US.UTF-8 already available."
fi

# ──────────────────────
# 7. Current user (the one running the script via sudo)
# ──────────────────────
if [[ -n "${SUDO_USER:-}" ]]; then
    ADMIN_USER="$SUDO_USER"
else
    ADMIN_USER="${USER:-$(logname 2>/dev/null || echo 'root')}"
fi

if [[ "$ADMIN_USER" == "root" ]]; then
    err "This script must be run with sudo from a non-root user, not directly as root."
fi

log "Detected admin user: $ADMIN_USER"
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

if [[ -n "$SSH_KEY_ARG" ]]; then
    # Non-interactive: key passed as argument
    echo "$SSH_KEY_ARG" > "/home/$HERMES_USER/.ssh/authorized_keys"
    chmod 600 "/home/$HERMES_USER/.ssh/authorized_keys"
    chown -R "$HERMES_USER:$HERMES_USER" "/home/$HERMES_USER/.ssh"
    log "SSH key added for $HERMES_USER (from --ssh-key argument)."
elif [[ -t 0 ]]; then
    # Interactive mode
    echo ""
    echo "┌────────────────────────────────────────────────────────────┐"
    echo "│ SSH KEY SETUP                                              │"
    echo "│                                                            │"
    echo "│ Paste the PUBLIC KEY from your LOCAL machine below.        │"
    echo "│                                                            │"
    echo "│ If you don't have one, generate it on your local PC:       │"
    echo "│   ssh-keygen -t ed25519 -C \"your-email@example.com\"        │"
    echo "│                                                            │"
    echo "│ Then copy the content of ~/.ssh/id_ed25519.pub             │"
    echo "│ (or ~/.ssh/id_rsa.pub)                                     │"
    echo "│                                                            │"
    echo "│ Paste it below and press Ctrl+D when done:                 │"
    echo "└────────────────────────────────────────────────────────────┘"
    echo ""
    echo -n "SSH public key: "
    read -r HERMES_SSH_KEY

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
else
    warn "Non-interactive mode and no --ssh-key provided. Skipping SSH key setup."
    warn "Add SSH key manually later:"
    warn "  echo 'ssh-ed25519 AAAA...' | sudo tee /home/$HERMES_USER/.ssh/authorized_keys"
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
duration=$SECONDS
mins=$((duration / 60))
secs=$((duration % 60))
if [[ $mins -gt 0 ]]; then
    elapsed="${mins}m ${secs}s"
else
    elapsed="${secs}s"
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          ✓ BOOTSTRAP COMPLETE            ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Duration${NC}  : ${CYAN}${elapsed}${NC}"
echo -e "  ${BOLD}Hostname${NC}  : ${CYAN}${NEW_HOSTNAME}${NC}"
echo -e "  ${BOLD}Timezone${NC} : ${CYAN}${TZ}${NC}"
echo ""
echo -e "  ${BOLD}Admin${NC}  : ${GREEN}${ADMIN_USER}${NC} (pre-existing, sudo)"
echo -e "  ${BOLD}Agent${NC}  : ${GREEN}${HERMES_USER}${NC} (no sudo, key-only)"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  ${CYAN}1.${NC} Verify SSH access for both users:"
echo "       ${BOLD}ssh ${ADMIN_USER}@<server-ip>${NC}"
echo "       ${BOLD}ssh ${HERMES_USER}@<server-ip>${NC}"
echo ""
echo -e "  ${CYAN}2.${NC} Run hardening.sh for security configuration:"
echo "       ${BOLD}sudo ./hardening.sh${NC}"
echo ""
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
