#!/bin/bash
#
# playwright.sh — Chromium OS libraries (apt). Browser binary is the
# official installer. hermes has no sudo, so this is an admin step.
#
# Usage:
#   sudo ./scripts/playwright.sh
#   sudo ./scripts/playwright.sh --deps   # same; kept for old docs
#

set -euo pipefail

DEFAULT_HERMES_USER="hermes"

TARGET_USER="$DEFAULT_HERMES_USER"
HERMES_HOME_ARG=""

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
NC=$'\033[0m'

log()  { echo -e "${GREEN}[PLAYWRIGHT]${NC} $1"; }
err()  { echo -e "${RED}[PLAYWRIGHT]${NC} $1" >&2; exit 1; }

usage() {
    cat <<EOF
Usage: $0 [--deps] [--user NAME] [--hermes-home PATH] [-h|--help]

Install Chromium OS libraries (\`npx playwright install-deps\`).
Must be root. The hermes user has no sudo.

The official Hermes installer already downloads Chromium into
~hermes/.cache/ms-playwright. This script does not unpack or download
the browser.

Options:
  --deps              Same as default (compat)
  --user NAME         Hermes account (default: hermes)
  --hermes-home PATH  Data dir (default: ~hermes/.hermes)
  -h, --help          Show this help message

After: as hermes, hermes doctor — Playwright Chromium (browser engine).
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --deps)
            shift
            ;;
        --user)
            [[ $# -ge 2 ]] || err "--user requires a name."
            TARGET_USER="$2"
            shift 2
            ;;
        --user=*)
            TARGET_USER="${1#*=}"
            shift
            ;;
        --hermes-home)
            [[ $# -ge 2 ]] || err "--hermes-home requires a path."
            HERMES_HOME_ARG="$2"
            shift 2
            ;;
        --hermes-home=*)
            HERMES_HOME_ARG="${1#*=}"
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

resolve_target_home() {
    local home
    home="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
    [[ -n "$home" && -d "$home" ]] \
        || err "Could not resolve home for '$TARGET_USER'."
    printf '%s' "$home"
}

resolve_hermes_home() {
    if [[ -n "$HERMES_HOME_ARG" ]]; then
        printf '%s' "$HERMES_HOME_ARG"
        return 0
    fi
    printf '%s/.hermes' "$(resolve_target_home)"
}

find_npx() {
    local hermes_home="$1"
    local target_home="$2"
    local candidate
    for candidate in \
        "$hermes_home/node/bin/npx" \
        "$target_home/.local/bin/npx"
    do
        if [[ -x "$candidate" ]]; then
            printf '%s' "$candidate"
            return 0
        fi
    done
    if command -v npx >/dev/null 2>&1; then
        command -v npx
        return 0
    fi
    return 1
}

[[ $EUID -eq 0 ]] || err "Needs root. As admin: sudo $0"

hermes_home="$(resolve_hermes_home)"
target_home="$(resolve_target_home)"
agent="${hermes_home}/hermes-agent"
[[ -d "$agent" ]] || err "Hermes Agent not found at $agent. Install Hermes first."

npx="$(find_npx "$hermes_home" "$target_home")" \
    || err "npx not found. Official install puts it under $hermes_home/node/bin or $target_home/.local/bin."

npx_dir="$(dirname "$npx")"
# npx shebang is /usr/bin/env node; sudo PATH has no hermes node.
export PATH="$npx_dir:$PATH"

log "Installing Chromium OS libraries (install-deps only)."
(
    cd "$agent"
    "$npx" playwright install-deps chromium
)
log "OS libraries installed. As $TARGET_USER: hermes doctor"
