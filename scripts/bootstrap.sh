#!/bin/bash
#
# bootstrap.sh — Initial system setup: creates hermes user, base configuration
# Run as root on a fresh Debian Server installation.
#
# Usage:
#   sudo ./bootstrap.sh --config /path/to/host.yaml
#   sudo ./bootstrap.sh   # uses bootstrap.yaml next to this script, if present
#
# Pre-condition: the admin user already exists (created during Debian OS
# installation). This script does NOT create the admin user — only hermes.
#
# Tooling pre-condition: mise and pinned yq must already be available
# (install once yourself — see docs/BOOTSTRAP.md). This script does not
# install mise/yq; it fail-fast checks then configures the host.
#
# Configuration is YAML-only. Interactive prompts and legacy flags
# (--hostname, --timezone, --ssh-key) are not supported.
# The script is standalone: inject any config path via --config.
#

set -euo pipefail
SECONDS=0

# ──────────────────────
# Defaults
# ──────────────────────
DEFAULT_TIMEZONE="UTC"
DEFAULT_HERMES_USER="hermes"
SCRIPT_VERSION="2.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(pwd)"
LEGACY_STATE_FILE="/var/lib/hermes-self-hosted/bootstrap.state"

# ──────────────────────
# State (resolved after ADMIN_USER is known)
# ──────────────────────
STATE_DIR=""
STATE_FILE=""
STORED_CONFIG_HASH=""
CONFIG_PATH=""
CONFIG_HASH=""
CONFIG_ARG=""
MISE_VERSION=""
CFG_HOSTNAME=""
CFG_TIMEZONE=""
CFG_HERMES_USER=""
CFG_SSH_PUBLIC_KEY=""
CFG_SSH_PUBLIC_KEY_FILE=""
HERMES_SSH_KEY=""
PREVIOUS_HOSTNAME=""

# ──────────────────────
# Helpers
# ──────────────────────
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
NC=$'\033[0m'

show_banner() {
    # Hardcoded FIGlet Slant wordmark (no figlet/ascii-banner runtime dependency).
    printf '\n%s' "$GREEN"
    cat <<'EOF'
    __  ____________  __  ______________
   / / / / ____/ __ \/  |/  / ____/ ___/
  / /_/ / __/ / /_/ / /|_/ / __/  \__ \
 / __  / /___/ _, _/ /  / / /___ ___/ /
/_/ /_/_____/_/ |_/_/  /_/_____//____/
EOF
    printf '%s' "$NC"
    printf '%sbootstrap v%s%s\n\n' "$CYAN" "$SCRIPT_VERSION" "$NC"
}

log()  { echo -e "${GREEN}[BOOTSTRAP]${NC} $1"; }
warn() { echo -e "${YELLOW}[BOOTSTRAP]${NC} $1"; }
err()  { echo -e "${RED}[BOOTSTRAP]${NC} $1" >&2; exit 1; }

usage() {
    cat <<EOF
Usage: $0 [--config PATH] [-h|--help]

Options:
  --config PATH   Path to a bootstrap YAML file (any path; schema must validate)
  -h, --help      Show this help message

Example:
  sudo ./bootstrap.sh --config ./bootstrap.yaml
EOF
    exit 0
}

legacy_flag_error() {
    err "Flag '$1' is no longer supported. Use --config with a YAML file."
}

# Run a command as ADMIN_USER with a login-like env and mise on PATH.
run_as_admin() {
    sudo -u "$ADMIN_USER" -H bash -lc "export PATH=\"\$HOME/.local/bin:\$PATH\"; $*"
}

yq_eval() {
    local expression="$1"
    local file="$2"
    run_as_admin "cd $(printf '%q' "$WORK_DIR") && mise exec -- yq eval $(printf '%q' "$expression") $(printf '%q' "$file")"
}

# ──────────────────────
# Parse arguments
# ──────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            [[ $# -ge 2 ]] || err "--config requires a path argument."
            CONFIG_ARG="$2"
            shift 2
            ;;
        --config=*)
            CONFIG_ARG="${1#*=}"
            shift
            ;;
        --hostname|--hostname=*|--timezone|--timezone=*|--ssh-key|--ssh-key=*)
            legacy_flag_error "${1%%=*}"
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

if [[ -n "${SUDO_USER:-}" ]]; then
    ADMIN_USER="$SUDO_USER"
else
    ADMIN_USER="${USER:-$(logname 2>/dev/null || echo 'root')}"
fi

if [[ "$ADMIN_USER" == "root" ]]; then
    err "This script must be run with sudo from a non-root user, not directly as root."
fi

ADMIN_HOME="$(getent passwd "$ADMIN_USER" | cut -d: -f6)"
[[ -n "$ADMIN_HOME" && -d "$ADMIN_HOME" ]] || err "Could not resolve home directory for admin user '$ADMIN_USER'."

STATE_DIR="${ADMIN_HOME}/.hermes-self-hosted"
STATE_FILE="${STATE_DIR}/bootstrap.state"

show_banner
log "Detected admin user: $ADMIN_USER"
log "State directory: $STATE_DIR"

# ──────────────────────
# Fail-fast preflight (no tool installs)
# ──────────────────────
resolve_config_path() {
    # Standalone tool: inject any config path via --config.
    # Without --config, only bootstrap.yaml next to this script is accepted.
    if [[ -n "$CONFIG_ARG" ]]; then
        if [[ -f "$CONFIG_ARG" ]]; then
            CONFIG_PATH="$(cd "$(dirname "$CONFIG_ARG")" && pwd)/$(basename "$CONFIG_ARG")"
            return 0
        fi
        err "Config file not found: $CONFIG_ARG"
    fi

    if [[ -f "${SCRIPT_DIR}/bootstrap.yaml" ]]; then
        CONFIG_PATH="${SCRIPT_DIR}/bootstrap.yaml"
        return 0
    fi

    err "No config found. Use --config PATH (or put bootstrap.yaml next to this script)."
}

# Require mise + yq already available. Bootstrap does not install them.
require_mise_yq() {
    if ! run_as_admin 'command -v mise >/dev/null 2>&1'; then
        err "mise/yq not ready. Install mise, then run: mise install (see docs/BOOTSTRAP.md)."
    fi

    if ! run_as_admin "cd $(printf '%q' "$WORK_DIR") && mise exec -- yq --version >/dev/null 2>&1"; then
        err "mise/yq not ready. Install mise, then run: mise install (see docs/BOOTSTRAP.md)."
    fi

    MISE_VERSION="$(run_as_admin 'mise --version' | head -n1 | tr -d '\r')"
    log "mise/yq ready: $MISE_VERSION"
}

resolve_config_path
log "Using config: $CONFIG_PATH"
require_mise_yq

# ──────────────────────
# Config load + validate
# ──────────────────────

validate_hostname() {
    local name="$1"
    [[ -n "$name" ]] || err "Config error: hostname is required."
    [[ "$name" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]] \
        || err "Config error: invalid hostname '$name' (use letters, digits, hyphens; max 63 chars)."
}

validate_timezone() {
    local tz="$1"
    if command -v timedatectl >/dev/null 2>&1; then
        if ! timedatectl list-timezones | grep -Fxq "$tz"; then
            err "Config error: invalid timezone '$tz'.
List valid zones with: timedatectl list-timezones"
        fi
    elif [[ ! -e "/usr/share/zoneinfo/$tz" ]]; then
        err "Config error: timezone '$tz' not found under /usr/share/zoneinfo."
    fi
}

validate_ssh_public_key() {
    local key="$1"
    [[ "$key" =~ ^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521)[[:space:]]+AAAA[A-Za-z0-9+/=]+ ]] \
        || err "Config error: SSH public key does not match a supported format (ssh-ed25519, ssh-rsa, ecdsa-sha2-nistp*)."
}

yq_str() {
    # Normalize yq null / empty to empty string
    local raw
    raw="$(yq_eval "$1" "$CONFIG_PATH")"
    raw="${raw%$'\r'}"
    if [[ -z "$raw" || "$raw" == "null" ]]; then
        printf ''
    else
        printf '%s' "$raw"
    fi
}

load_and_validate_config() {
    CONFIG_HASH="$(sha256sum "$CONFIG_PATH" | awk '{print $1}')"
    log "Config content hash: $CONFIG_HASH"

    CFG_HOSTNAME="$(yq_str '.hostname')"
    CFG_TIMEZONE="$(yq_str '.timezone')"
    CFG_HERMES_USER="$(yq_str '.hermes.user')"
    CFG_SSH_PUBLIC_KEY="$(yq_str '.hermes.ssh_public_key')"
    CFG_SSH_PUBLIC_KEY_FILE="$(yq_str '.hermes.ssh_public_key_file')"

    [[ -n "$CFG_TIMEZONE" ]] || CFG_TIMEZONE="$DEFAULT_TIMEZONE"
    [[ -n "$CFG_HERMES_USER" ]] || CFG_HERMES_USER="$DEFAULT_HERMES_USER"

    validate_hostname "$CFG_HOSTNAME"
    validate_timezone "$CFG_TIMEZONE"

    if [[ -n "$CFG_SSH_PUBLIC_KEY" && -n "$CFG_SSH_PUBLIC_KEY_FILE" ]]; then
        err "Config error: Both ssh_public_key and ssh_public_key_file are set.
Choose one or the other — not both."
    fi

    if [[ -n "$CFG_SSH_PUBLIC_KEY_FILE" ]]; then
        local key_file="$CFG_SSH_PUBLIC_KEY_FILE"
        # Expand ~ for admin home if present
        if [[ "$key_file" == ~* ]]; then
            key_file="${key_file/#\~/$ADMIN_HOME}"
        fi
        [[ -f "$key_file" ]] || err "Config error: ssh_public_key_file not found: $CFG_SSH_PUBLIC_KEY_FILE"
        [[ -r "$key_file" ]] || err "Config error: ssh_public_key_file not readable: $CFG_SSH_PUBLIC_KEY_FILE"
        HERMES_SSH_KEY="$(tr -d '\r' < "$key_file" | head -n1)"
        validate_ssh_public_key "$HERMES_SSH_KEY"
    elif [[ -n "$CFG_SSH_PUBLIC_KEY" ]]; then
        HERMES_SSH_KEY="$CFG_SSH_PUBLIC_KEY"
        validate_ssh_public_key "$HERMES_SSH_KEY"
    else
        warn "Neither hermes.ssh_public_key nor hermes.ssh_public_key_file is set. SSH key setup will be skipped."
        HERMES_SSH_KEY=""
    fi

    log "Config validated (hostname=$CFG_HOSTNAME timezone=$CFG_TIMEZONE hermes.user=$CFG_HERMES_USER)."
}

load_and_validate_config

# ──────────────────────
# State: migrate legacy, load, compare config hash
# ──────────────────────
state_get() {
    # Read KEY=value from a state file without sourcing (avoids clobbering live vars).
    local file="$1"
    local key="$2"
    local line
    line="$(grep -E "^${key}=" "$file" 2>/dev/null | tail -n1 || true)"
    printf '%s' "${line#"${key}="}"
}

migrate_legacy_state() {
    if [[ ! -f "$LEGACY_STATE_FILE" ]]; then
        return 0
    fi

    if [[ -f "$STATE_FILE" ]]; then
        warn "Legacy state at $LEGACY_STATE_FILE ignored because $STATE_FILE already exists. Remove the legacy file manually."
        return 0
    fi

    log "Legacy state detected at $LEGACY_STATE_FILE — migrating to $STATE_FILE."
    mkdir -p "$STATE_DIR"
    chown "$ADMIN_USER:$ADMIN_USER" "$STATE_DIR"

    local old_completed old_script_version old_hostname old_admin old_hermes
    old_completed="$(state_get "$LEGACY_STATE_FILE" COMPLETED_AT)"
    old_script_version="$(state_get "$LEGACY_STATE_FILE" SCRIPT_VERSION)"
    old_hostname="$(state_get "$LEGACY_STATE_FILE" HOSTNAME)"
    old_admin="$(state_get "$LEGACY_STATE_FILE" ADMIN_USER)"
    old_hermes="$(state_get "$LEGACY_STATE_FILE" HERMES_USER)"

    cat > "$STATE_FILE" <<EOF
COMPLETED_AT=${old_completed}
SCRIPT_VERSION=${old_script_version}
HOSTNAME=${old_hostname}
ADMIN_USER=${old_admin}
HERMES_USER=${old_hermes}
PREVIOUS_HOSTNAME=${old_hostname}
CONFIG_HASH=
MISE_VERSION=
EOF
    chown "$ADMIN_USER:$ADMIN_USER" "$STATE_FILE"
    chmod 644 "$STATE_FILE"

    if rm -f "$LEGACY_STATE_FILE"; then
        rmdir /var/lib/hermes-self-hosted 2>/dev/null || true
        log "Legacy state migrated and removed."
    else
        warn "Migrated state written to $STATE_FILE, but could not remove $LEGACY_STATE_FILE — remove it manually."
    fi
}

load_bootstrap_state() {
    migrate_legacy_state

    if [[ -f "$STATE_FILE" ]]; then
        log "Previous bootstrap detected ($STATE_FILE), running in re-run mode."
        STORED_CONFIG_HASH="$(state_get "$STATE_FILE" CONFIG_HASH)"
        if [[ -n "$STORED_CONFIG_HASH" && "$STORED_CONFIG_HASH" != "$CONFIG_HASH" ]]; then
            warn "Config content changed since last bootstrap (stored=$STORED_CONFIG_HASH current=$CONFIG_HASH)."
        elif [[ -n "$STORED_CONFIG_HASH" ]]; then
            log "Config content unchanged since last bootstrap."
        fi
    elif id "$CFG_HERMES_USER" &>/dev/null; then
        log "Legacy bootstrap detected ($CFG_HERMES_USER user exists), running in re-run mode."
    fi
}

write_bootstrap_state() {
    mkdir -p "$STATE_DIR"
    chown "$ADMIN_USER:$ADMIN_USER" "$STATE_DIR"
    cat > "$STATE_FILE" <<EOF
COMPLETED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SCRIPT_VERSION=${SCRIPT_VERSION}
HOSTNAME=${NEW_HOSTNAME}
ADMIN_USER=${ADMIN_USER}
HERMES_USER=${HERMES_USER}
PREVIOUS_HOSTNAME=${PREVIOUS_HOSTNAME}
CONFIG_HASH=${CONFIG_HASH}
MISE_VERSION=${MISE_VERSION}
EOF
    chown "$ADMIN_USER:$ADMIN_USER" "$STATE_FILE"
    chmod 644 "$STATE_FILE"
    log "Bootstrap state written to $STATE_FILE."
}

load_bootstrap_state

# Apply config values for the rest of the script
NEW_HOSTNAME="$CFG_HOSTNAME"
TZ="$CFG_TIMEZONE"
HERMES_USER="$CFG_HERMES_USER"
# Hostname before this run mutates it (stored in state for uninstall / audit)
PREVIOUS_HOSTNAME="$(hostname)"

# ──────────────────────
# 1. Fix /etc/hosts (avoid sudo: unable to resolve host)
# ──────────────────────
CURRENT_HOSTNAME=$(hostname)
if ! grep -qi "$CURRENT_HOSTNAME" /etc/hosts 2>/dev/null; then
    log "Fixing /etc/hosts: adding $CURRENT_HOSTNAME"
    if grep -q '^127\.0\.1\.1' /etc/hosts; then
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
if [[ -z "$(find /var/lib/apt/lists -maxdepth 0 -mmin -60 2>/dev/null)" ]]; then
    apt update
else
    log "Package lists refreshed less than 60 min ago, skipping apt update."
fi
apt upgrade -y
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
# 4. Hostname (from config)
# ──────────────────────
if [[ "$(hostname)" == "$NEW_HOSTNAME" ]]; then
    log "Hostname already set to $NEW_HOSTNAME, skipping."
else
    log "Setting hostname: $NEW_HOSTNAME"
    hostnamectl set-hostname "$NEW_HOSTNAME"
    CURRENT_HOSTNAME="$NEW_HOSTNAME"
    if grep -q '^127\.0\.1\.1' /etc/hosts; then
        sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$CURRENT_HOSTNAME/" /etc/hosts
    else
        printf '127.0.1.1\t%s\n' "$CURRENT_HOSTNAME" >> /etc/hosts
    fi
fi

# ──────────────────────
# 5. Timezone (from config)
# ──────────────────────
log "Setting timezone: $TZ"
export DEBIAN_FRONTEND=noninteractive
timedatectl set-timezone "$TZ" 2>/dev/null || {
    ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime
    echo "$TZ" > /etc/timezone
}
log "Timezone set to $TZ."

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
# 7. Admin user (already resolved)
# ──────────────────────
log "Admin user: $ADMIN_USER (pre-existing from Debian installation)"

# ──────────────────────
# 8. Hermes agent user
# ──────────────────────
log "Creating hermes user ($HERMES_USER)..."

if id "$HERMES_USER" &>/dev/null; then
    warn "User '$HERMES_USER' already exists, skipping creation."
else
    adduser --disabled-password --gecos "Hermes Agent" "$HERMES_USER"
    passwd -l "$HERMES_USER"
    log "User '$HERMES_USER' created (key-only auth, no password, no sudo)."
fi

# ──────────────────────
# 9. Hermes SSH key (from config)
# ──────────────────────
log "Setting up SSH for $HERMES_USER..."

if [[ -f "/home/$HERMES_USER/.ssh/authorized_keys" ]] && [[ -s "/home/$HERMES_USER/.ssh/authorized_keys" ]]; then
    warn "authorized_keys already exists, skipping. Remove manually if you want to replace."
else
    mkdir -p "/home/$HERMES_USER/.ssh"
    chmod 700 "/home/$HERMES_USER/.ssh"

    if [[ -n "$HERMES_SSH_KEY" ]]; then
        echo "$HERMES_SSH_KEY" > "/home/$HERMES_USER/.ssh/authorized_keys"
        chmod 600 "/home/$HERMES_USER/.ssh/authorized_keys"
        chown -R "$HERMES_USER:$HERMES_USER" "/home/$HERMES_USER/.ssh"
        log "SSH key added for $HERMES_USER (from config)."
    else
        warn "No SSH key in config for $HERMES_USER. Skipping key setup."
        warn "Add a key later:"
        warn "  echo 'ssh-ed25519 AAAA...' | sudo tee /home/$HERMES_USER/.ssh/authorized_keys"
        touch "/home/$HERMES_USER/.ssh/authorized_keys"
        chmod 600 "/home/$HERMES_USER/.ssh/authorized_keys"
        chown -R "$HERMES_USER:$HERMES_USER" "/home/$HERMES_USER/.ssh"
    fi
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
if passwd -S root 2>/dev/null | grep -q " L "; then
    log "Root account already locked, skipping."
else
    log "Locking root account..."
    passwd -l root
    log "Root account locked."
fi

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

write_bootstrap_state

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          ✓ BOOTSTRAP COMPLETE            ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Duration${NC}  : ${CYAN}${elapsed}${NC}"
echo -e "  ${BOLD}Hostname${NC}  : ${CYAN}${NEW_HOSTNAME}${NC}"
echo -e "  ${BOLD}Timezone${NC}  : ${CYAN}${TZ}${NC}"
echo -e "  ${BOLD}Config${NC}    : ${CYAN}${CONFIG_PATH}${NC}"
echo ""
echo -e "  ${BOLD}Admin${NC}  : ${GREEN}${ADMIN_USER}${NC} (pre-existing, sudo)"
echo -e "  ${BOLD}Agent${NC}  : ${GREEN}${HERMES_USER}${NC} (no sudo, key-only)"
echo -e "  ${BOLD}State${NC}  : ${CYAN}${STATE_FILE}${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  ${CYAN}1.${NC} Verify SSH access for both users:"
echo "       ${BOLD}ssh ${ADMIN_USER}@<server-ip>${NC}"
echo "       ${BOLD}ssh ${HERMES_USER}@<server-ip>${NC}"
echo ""
echo -e "  ${CYAN}2.${NC} Run hardening.sh for security configuration:"
echo "       ${BOLD}sudo ./scripts/hardening.sh${NC}"
echo ""
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
