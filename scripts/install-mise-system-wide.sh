#!/bin/bash
#
# install-mise-system-wide.sh — Create /etc/profile.d/mise.sh for system-wide mise activation
#
# Makes mise shims and activation available to all users on login.
#
# Usage:
#   sudo ./install-mise-system-wide.sh
#   sudo ./install-mise-system-wide.sh --remove
#
# Options:
#   --remove    Remove the system-wide mise configuration
#   -h, --help  Show this help message

set -euo pipefail

# ──────────────────────
# Helpers
# ──────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[MISE-SYSTEM]${NC} $1"; }
warn() { echo -e "${YELLOW}[MISE-SYSTEM]${NC} $1"; }
err()  { echo -e "${RED}[MISE-SYSTEM]${NC} $1" >&2; exit 1; }

# ──────────────────────
# Constants
# ──────────────────────
PROFILE_D_FILE="/etc/profile.d/mise.sh"
# ──────────────────────
# Usage
# ──────────────────────
usage() {
    cat <<EOF
Usage: $0 [options]

Create /etc/profile.d/mise.sh to activate mise system-wide.
All users will have mise shims in PATH and mise activation on login.

Options:
  --remove    Remove the system-wide mise configuration
  -h, --help  Show this help message

Must be run as root (sudo).

Examples:
  sudo ./install-mise-system-wide.sh
  sudo ./install-mise-system-wide.sh --remove
EOF
    exit 0
}

# ──────────────────────
# Parse arguments
# ──────────────────────
REMOVE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --remove)
            REMOVE=true
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

if [[ ! -d /etc/profile.d ]]; then
    err "/etc/profile.d/ does not exist. This system may not support profile.d."
fi

# ──────────────────────
# Remove mode
# ──────────────────────
if [[ "$REMOVE" == true ]]; then
    if [[ -f "$PROFILE_D_FILE" ]]; then
        rm -f "$PROFILE_D_FILE"
        log "Removed $PROFILE_D_FILE"
        log "Mise system-wide configuration removed. Changes take effect in new login sessions."
    else
        warn "$PROFILE_D_FILE does not exist. Nothing to remove."
    fi
    exit 0
fi

# ──────────────────────
# Check mise installation
# ──────────────────────
if ! command -v mise &>/dev/null; then
    err "mise is not installed. Install mise first (see https://mise.jdx.dev)."
fi

# ──────────────────────
# Check idempotency
# ──────────────────────
# shellcheck disable=SC2016
SHIM_LINE='export PATH="${HOME}/.local/share/mise/shims:${PATH}"'
# shellcheck disable=SC2016
ACTIVATE_LINE='eval "$(mise activate bash)"'

if [[ -f "$PROFILE_D_FILE" ]]; then
    if grep -qF "$SHIM_LINE" "$PROFILE_D_FILE" && grep -qF "$ACTIVATE_LINE" "$PROFILE_D_FILE"; then
        log "$PROFILE_D_FILE already exists with correct content. Nothing to do."
        exit 0
    fi

    if [[ -t 0 ]]; then
        echo ""
        echo "┌────────────────────────────────────────────────────────────┐"
        echo "│ EXISTING CONFIGURATION FOUND                               │"
        echo "│                                                            │"
        echo "│ $PROFILE_D_FILE already exists but has different content.   │"
        echo "│ Overwrite it? [y/N]                                        │"
        echo "└────────────────────────────────────────────────────────────┘"
        echo ""
        read -rp "Overwrite? [y/N]: " CONFIRM
        if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
            log "Skipping. Existing configuration preserved."
            exit 0
        fi
    else
        warn "Non-interactive mode and $PROFILE_D_FILE differs. Use --remove first to start fresh."
        exit 1
    fi
fi

# ──────────────────────
# Create profile.d script
# ──────────────────────
log "Creating $PROFILE_D_FILE..."

cat > "$PROFILE_D_FILE" << 'MISEEOF'
# /etc/profile.d/mise.sh — System-wide mise configuration
#
# Adds mise shims to PATH and activates mise for all users.
# This file is sourced by all Bourne-compatible login shells.

# Add mise shims to PATH for all users
export PATH="${HOME}/.local/share/mise/shims:${PATH}"

# Activate mise (enables completions and aliases)
if command -v mise &>/dev/null; then
    eval "$(mise activate bash)"
fi
MISEEOF

chmod 644 "$PROFILE_D_FILE"

# ──────────────────────
# Done
# ──────────────────────
echo ""
echo "=================================="
echo "  MISE SYSTEM-WIDE INSTALLED"
echo "=================================="
echo ""
echo "  File: $PROFILE_D_FILE"
echo ""
echo "  Changes take effect in NEW login sessions."
echo "  To activate immediately in this session, run:"
echo "    source $PROFILE_D_FILE"
echo ""
echo "  To verify after logging in again:"
echo "    echo \"\$PATH\" | grep mise"
echo "    mise doctor"
echo ""
echo "  To remove:"
echo "    sudo $0 --remove"
echo "=================================="
