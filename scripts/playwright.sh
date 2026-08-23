#!/bin/bash
#
# playwright.sh — Enable Playwright Chromium after a --skip-browser install
#
# Does NOT run `npx playwright install chromium` (Playwright 1.58.2 +
# bundled Node 26 hangs on extract). Reuses cache or unpacks/downloads
# the Chrome for Testing zip. OS libs are a separate admin step.
#
# Usage:
#   ./scripts/playwright.sh              # as hermes: unpack / reuse / download
#   sudo ./scripts/playwright.sh --deps  # as admin: install-deps only
#

set -euo pipefail

DEFAULT_HERMES_USER="hermes"
# Official pin today (playwright-core 1.58.2 browsers.json).
DEFAULT_CHROMIUM_REV="1208"
DEFAULT_BROWSER_VERSION="145.0.7632.6"

DO_DEPS=false
TARGET_USER="$DEFAULT_HERMES_USER"
HERMES_HOME_ARG=""

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
NC=$'\033[0m'

log()  { echo -e "${GREEN}[PLAYWRIGHT]${NC} $1"; }
warn() { echo -e "${YELLOW}[PLAYWRIGHT]${NC} $1"; }
err()  { echo -e "${RED}[PLAYWRIGHT]${NC} $1" >&2; exit 1; }

usage() {
    cat <<EOF
Usage: $0 [--deps] [--user NAME] [--hermes-home PATH] [-h|--help]

Enable Playwright Chromium after the official installer --skip-browser.

Do not run the installer follow-up:

  cd ~/.hermes/hermes-agent && npx playwright install chromium

That command hangs on extract (Playwright 1.58.2 + Node 26). This script
reuses ~/.cache/ms-playwright, unpacks an existing zip, or downloads the
zip from the Playwright CDN. It never starts that extract.

Who runs which part
  hermes (no sudo)   $0
                     Unpack / reuse / download Chromium into
                     ~/.cache/ms-playwright

  admin (sudo)       $0 --deps
                     OS libraries only (\`npx playwright install-deps\`).
                     The hermes user has no sudo.

Options:
  --deps              Install apt deps (must be root)
  --user NAME         Hermes account (default: hermes). Used with --deps
                      to find that user's install
  --hermes-home PATH  Data dir (default: ~hermes/.hermes or \$HERMES_HOME)
  -h, --help          Show this help message

After both steps, as hermes: hermes doctor
Look for Playwright Chromium (browser engine).
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --deps)
            DO_DEPS=true
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
    if [[ -n "${HERMES_HOME:-}" && $EUID -ne 0 ]]; then
        printf '%s' "$HERMES_HOME"
        return 0
    fi
    printf '%s/.hermes' "$(resolve_target_home)"
}

find_browsers_json() {
    local agent="$1"
    local f
    local candidates=(
        "$agent/node_modules/playwright-core/browsers.json"
        "$agent/apps/desktop/node_modules/playwright-core/browsers.json"
    )

    for f in "${candidates[@]}"; do
        if [[ -f "$f" ]]; then
            printf '%s' "$f"
            return 0
        fi
    done

    shopt -s nullglob
    for f in "$agent"/venv/lib/python*/site-packages/playwright/driver/package/browsers.json; do
        if [[ -f "$f" ]]; then
            printf '%s' "$f"
            return 0
        fi
    done
    shopt -u nullglob
    return 1
}

read_chromium_pin() {
    local json="$1"
    python3 - "$json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
for browser in data.get("browsers", []):
    if browser.get("name") == "chromium":
        rev = str(browser.get("revision", "")).strip()
        ver = str(browser.get("browserVersion", "")).strip()
        if rev and ver:
            print(f"{rev} {ver}")
            sys.exit(0)
        break
sys.exit(1)
PY
}

find_existing_zip() {
    local candidate newest="" newest_m=0 m
    local zips=()

    shopt -s nullglob
    zips=(/tmp/playwright-download-*/playwright-download-chromium-*.zip)
    shopt -u nullglob

    for candidate in "${zips[@]}"; do
        [[ -f "$candidate" ]] || continue
        m="$(stat -c %Y "$candidate")"
        if [[ "$m" -gt "$newest_m" ]]; then
            newest="$candidate"
            newest_m="$m"
        fi
    done

    if [[ -n "$newest" ]]; then
        printf '%s' "$newest"
        return 0
    fi

    if [[ -f /tmp/chrome-linux64.zip ]]; then
        printf '%s' /tmp/chrome-linux64.zip
        return 0
    fi

    return 1
}

zip_looks_complete() {
    local zip="$1"
    local size
    [[ -f "$zip" ]] || return 1
    size="$(stat -c %s "$zip")"
    # Real chrome-linux64.zip is ~168 MB. Reject leftovers / partial curls.
    [[ "$size" -ge 10000000 ]] || return 1
    python3 - "$zip" <<'PY'
import sys, zipfile
try:
    with zipfile.ZipFile(sys.argv[1]) as zf:
        bad = zf.testzip()
        if bad is not None:
            sys.exit(1)
except zipfile.BadZipFile:
    sys.exit(1)
sys.exit(0)
PY
}

extract_zip() {
    local zip="$1"
    local dest="$2"
    mkdir -p "$dest"
    if command -v unzip >/dev/null 2>&1; then
        unzip -o -q "$zip" -d "$dest"
    else
        python3 - "$zip" "$dest" <<'PY'
import sys, zipfile
zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])
PY
    fi
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

install_deps() {
    local hermes_home agent npx target_home

    [[ $EUID -eq 0 ]] || err "install-deps needs root. As admin: sudo $0 --deps"

    hermes_home="$(resolve_hermes_home)"
    target_home="$(resolve_target_home)"
    agent="${hermes_home}/hermes-agent"
    [[ -d "$agent" ]] || err "Hermes Agent not found at $agent. Install Hermes first."

    npx="$(find_npx "$hermes_home" "$target_home")" \
        || err "npx not found. Official install puts it under $hermes_home/node/bin or $target_home/.local/bin."

    log "Installing Chromium OS libraries (install-deps only; no browser extract)."
    (
        cd "$agent"
        # install-deps is apt packages. Never `playwright install chromium`.
        "$npx" playwright install-deps chromium
    )
    log "OS libraries installed. As $TARGET_USER run: $0"
}

enable_chromium() {
    local hermes_home agent cache dest chrome json pin rev ver zip url
    local tmp_zip="/tmp/chrome-linux64.zip"

    if [[ $EUID -eq 0 ]]; then
        err "Enable Chromium as $TARGET_USER (no sudo). As admin: sudo $0 --deps"
    fi

    if [[ "$(id -un)" != "$TARGET_USER" ]]; then
        err "Run this as $TARGET_USER (no sudo). As admin: sudo $0 --deps"
    fi

    hermes_home="$(resolve_hermes_home)"
    agent="${hermes_home}/hermes-agent"
    [[ -d "$agent" ]] || err "Hermes Agent not found at $agent. Install Hermes first (with --skip-browser)."

    rev="$DEFAULT_CHROMIUM_REV"
    ver="$DEFAULT_BROWSER_VERSION"
    if json="$(find_browsers_json "$agent")"; then
        if pin="$(read_chromium_pin "$json")"; then
            rev="${pin%% *}"
            ver="${pin#* }"
            log "Using Chromium pin from $json (revision $rev, $ver)."
        else
            warn "Could not parse $json; using Playwright 1.58.2 defaults (revision $rev, $ver)."
        fi
    else
        log "No browsers.json under $agent; using Playwright 1.58.2 defaults (revision $rev, $ver)."
    fi

    if [[ -n "${PLAYWRIGHT_BROWSERS_PATH:-}" && "${PLAYWRIGHT_BROWSERS_PATH}" != "0" ]]; then
        cache="$PLAYWRIGHT_BROWSERS_PATH"
    else
        cache="${HOME}/.cache/ms-playwright"
    fi
    dest="${cache}/chromium-${rev}"
    chrome="${dest}/chrome-linux64/chrome"

    rm -f "${cache}/__dirlock"

    if [[ -x "$chrome" ]]; then
        log "Chromium already present: $chrome"
        log "If hermes doctor is still red, as admin: sudo $0 --deps"
        return 0
    fi

    if [[ -d "$dest" ]]; then
        warn "Incomplete cache at $dest — removing leftover extract."
        rm -rf "$dest"
    fi

    zip=""
    if zip="$(find_existing_zip)" && zip_looks_complete "$zip"; then
        log "Reusing existing zip: $zip"
    else
        if [[ -n "$zip" ]]; then
            warn "Ignoring incomplete zip: $zip"
        fi
        url="https://cdn.playwright.dev/builds/cft/${ver}/linux64/chrome-linux64.zip"
        command -v curl >/dev/null 2>&1 || err "curl is required to download Chromium."
        log "Downloading Chromium from Playwright CDN (not via npx extract)."
        curl -fL --retry 3 --retry-delay 2 --progress-bar -o "$tmp_zip" "$url"
        zip="$tmp_zip"
        zip_looks_complete "$zip" || err "Downloaded zip looks incomplete: $zip"
    fi

    log "Unpacking into $dest"
    extract_zip "$zip" "$dest"

    [[ -x "$chrome" ]] || err "Unpack finished but chrome is missing: $chrome"

    log "Chromium ready: $chrome"
    log "If hermes doctor is still red, as admin: sudo $0 --deps"
}

if [[ "$DO_DEPS" == true ]]; then
    install_deps
else
    enable_chromium
fi
