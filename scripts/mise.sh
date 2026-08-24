#!/bin/bash
#
# mise.sh — Install, activate, or remove mise for this repo
#
# Two official installer paths (https://mise.jdx.dev/installing-mise.html):
#   install                 curl https://mise.run | sh
#                           → ~/.local/bin/mise (admin user)
#   install --system-wide   curl https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh
#                           → /usr/local/bin/mise + /etc/profile.d/mise.sh
#
# Usage:
#   ./scripts/mise.sh install
#   sudo ./scripts/mise.sh install --system-wide
#   sudo ./scripts/mise.sh system-wide
#   sudo ./scripts/mise.sh system-wide --remove
#   ./scripts/mise.sh uninstall
#   sudo ./scripts/mise.sh uninstall --system-wide
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_D_FILE="/etc/profile.d/mise.sh"
SHARED_MISE="/usr/local/bin/mise"

# shellcheck disable=SC2016
SHIM_LINE='export PATH="${HOME}/.local/share/mise/shims:${PATH}"'
# shellcheck disable=SC2016
ACTIVATE_LINE='eval "$(mise activate bash)"'

CMD=""
FLAG_SYSTEM_WIDE=false
FLAG_REMOVE=false
REPO_ROOT=""
TARGET_USER=""
TARGET_HOME=""

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
NC=$'\033[0m'

log()  { echo -e "${GREEN}[MISE]${NC} $1"; }
warn() { echo -e "${YELLOW}[MISE]${NC} $1"; }
err()  { echo -e "${RED}[MISE]${NC} $1" >&2; exit 1; }

usage() {
    cat <<EOF
Usage: $0 <command> [options]

Manage mise (binary + pinned host tools from mise.host.toml) and optional
system-wide install. Bootstrap does not install mise — run this first.

The local toolchain is root mise.toml (\`mise install\` with no -E).
This script always uses -E host and ignores root mise.toml.

Two official installer paths (https://mise.jdx.dev/installing-mise.html):
  install                 curl https://mise.run | sh
                          → ~/.local/bin/mise (admin user)
  install --system-wide   curl https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh
                          → /usr/local/bin/mise + /etc/profile.d/mise.sh

Commands:
  install         Method 1: per-user official installer + host pins
  system-wide     Method 2: shared binary + profile.d (requires root)
  uninstall       Remove mise, pinned tools, and user bashrc activation

Options:
  --system-wide   With install: method 2 + profile.d + host pins
                  With uninstall: also remove shared binary and profile.d
  --remove        With system-wide: delete profile.d only (keep shared binary)
  -h, --help      Show this help message

Examples:
  $0 install
  sudo $0 install --system-wide
  sudo $0 system-wide
  sudo $0 system-wide --remove
  $0 uninstall
  sudo $0 uninstall --system-wide
EOF
}

require_root() {
    [[ $EUID -eq 0 ]] || err "This command must be run as root (use sudo)."
}

require_curl() {
    command -v curl >/dev/null 2>&1 \
        || err "curl is required to install mise. On Debian: sudo apt install -y curl (see docs/INSTALLATION.md)."
}

require_profile_d_dir() {
    [[ -d /etc/profile.d ]] || err "/etc/profile.d/ does not exist. This system may not support profile.d."
}

# PATH used when invoking mise as the admin user (covers both installer paths).
target_path() {
    printf '%s\n' "${TARGET_HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin"
}

resolve_target_user() {
    if [[ $EUID -eq 0 ]]; then
        if [[ -z "${SUDO_USER:-}" || "$SUDO_USER" == "root" ]]; then
            err "Run with sudo from a non-root admin user, not directly as root."
        fi
        TARGET_USER="$SUDO_USER"
    else
        TARGET_USER="${USER:-$(id -un)}"
        if [[ "$TARGET_USER" == "root" ]]; then
            err "Run as a non-root admin user (or: sudo $0 ...)."
        fi
    fi
    TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
    [[ -n "$TARGET_HOME" && -d "$TARGET_HOME" ]] \
        || err "Could not resolve home directory for '${TARGET_USER}'."
}

is_repo_root() {
    [[ -f "$1/mise.toml" && -f "$1/mise.host.toml" ]]
}

resolve_repo_root() {
    if is_repo_root "$PWD"; then
        REPO_ROOT="$PWD"
        return 0
    fi
    local candidate
    candidate="$(cd "${SCRIPT_DIR}/.." && pwd)"
    if is_repo_root "$candidate"; then
        REPO_ROOT="$candidate"
        return 0
    fi
    err "mise.toml / mise.host.toml not found in ${PWD} or ${candidate}. Run from the repo root."
}

# Host pins: mise.host.toml via -E host. Ignore root mise.toml so
# workstation tools are not installed on the server.
# MISE_IGNORED_CONFIG_PATHS is early-init — must be env, not mise.toml.
run_mise_host() {
    # $* is a pre-quoted command fragment for bash -c (install / exec -- …).
    # shellcheck disable=SC2086
    run_as_target "cd $(printf '%q' "$REPO_ROOT") && MISE_IGNORED_CONFIG_PATHS=$(printf '%q' "${REPO_ROOT}/mise.toml") mise -E host $*"
}

run_as_target() {
    local cmd="$1"
    if [[ $EUID -eq 0 ]]; then
        sudo -u "$TARGET_USER" -H env "HOME=${TARGET_HOME}" \
            PATH="$(target_path)" \
            bash -c "$cmd"
    else
        PATH="${HOME}/.local/bin:/usr/local/bin:${PATH}" bash -c "$cmd"
    fi
}

find_mise() {
    local candidate from_user
    if [[ -n "${TARGET_HOME:-}" ]]; then
        for candidate in \
            "${TARGET_HOME}/.local/bin/mise" \
            "$SHARED_MISE" \
            "${TARGET_HOME}/.local/share/mise/shims/mise"
        do
            if [[ -x "$candidate" ]] && ! is_uninstall_stub "$candidate"; then
                printf '%s\n' "$candidate"
                return 0
            fi
        done
    elif [[ -x "$SHARED_MISE" ]] && ! is_uninstall_stub "$SHARED_MISE"; then
        printf '%s\n' "$SHARED_MISE"
        return 0
    fi
    if [[ $EUID -eq 0 && -n "${TARGET_USER:-}" ]]; then
        from_user="$(sudo -u "$TARGET_USER" -H env "HOME=${TARGET_HOME}" \
            PATH="$(target_path)" \
            bash -c 'command -v mise' 2>/dev/null || true)"
        if [[ -n "$from_user" ]] && ! is_uninstall_stub "$from_user"; then
            printf '%s\n' "$from_user"
            return 0
        fi
    elif [[ $EUID -ne 0 ]]; then
        if PATH="${HOME}/.local/bin:/usr/local/bin:${PATH}" command -v mise >/dev/null 2>&1; then
            from_user="$(PATH="${HOME}/.local/bin:/usr/local/bin:${PATH}" command -v mise)"
            if [[ -n "$from_user" ]] && ! is_uninstall_stub "$from_user"; then
                printf '%s\n' "$from_user"
                return 0
            fi
        fi
    fi
    return 1
}

# Method 1: official installer as the admin user → ~/.local/bin/mise
install_user_binary() {
    local existing
    clear_uninstall_stub "${TARGET_HOME}/.local/bin/mise"
    existing="$(find_mise || true)"
    if [[ -n "$existing" ]]; then
        log "mise already installed (${existing})."
        return 0
    fi
    require_curl
    log "Installing mise for ${TARGET_USER} (official installer, per-user)..."
    run_as_target 'curl -fsSL https://mise.run | sh'
    if [[ ! -x "${TARGET_HOME}/.local/bin/mise" ]]; then
        err "mise installer finished but mise was not found in ${TARGET_HOME}/.local/bin."
    fi
}

# Method 2: official installer as root → /usr/local/bin/mise
# Do not copy or symlink a user binary here.
install_shared_binary() {
    require_root
    clear_uninstall_stub "$SHARED_MISE"
    if [[ -x "$SHARED_MISE" ]]; then
        log "mise already installed at ${SHARED_MISE}."
        return 0
    fi
    require_curl
    log "Installing mise to ${SHARED_MISE} (official installer, MISE_INSTALL_PATH)..."
    curl -fsSL https://mise.run | MISE_INSTALL_PATH="$SHARED_MISE" sh
    if [[ ! -x "$SHARED_MISE" ]]; then
        err "mise installer finished but ${SHARED_MISE} was not found."
    fi
}

remove_path() {
    local path="$1"
    if [[ ! -e "$path" && ! -L "$path" ]]; then
        return 0
    fi
    rm -rf "$path"
    log "Removed $path"
}

is_uninstall_stub() {
    [[ -f "$1" ]] || return 1
    # Real mise is ELF; do not read it (bash warns on NUL in $(sed)).
    [[ "$(head -c 2 "$1" 2>/dev/null || true)" == "#!" ]] || return 1
    grep -q '^# mise-uninstall-stub$' "$1"
}

clear_uninstall_stub() {
    if is_uninstall_stub "$1"; then
        rm -f "$1"
    fi
}

# Child cannot unset the parent's PROMPT_COMMAND. Leftover `mise activate`
# calls this path as hook-env; the stub uses that once, then deletes itself.
# ponytail: /usr/local/bin is not unlinkable by the parent; stub stays until
# next sudo install/uninstall (clear_uninstall_stub)
plant_hook_stub() {
    local dest="$1"
    local dest_q
    dest_q="$(printf '%q' "$dest")"
    mkdir -p "$(dirname "$dest")"
    if [[ "$dest" == "$SHARED_MISE" ]]; then
        cat > "$dest" << 'EOF'
#!/bin/sh
# mise-uninstall-stub
[ "${1-}" = "hook-env" ] || exit 127
cat <<'HOOK'
unset -f _mise_hook 2>/dev/null || true
PROMPT_COMMAND="${PROMPT_COMMAND-}"
PROMPT_COMMAND="${PROMPT_COMMAND//_mise_hook/}"
PROMPT_COMMAND="${PROMPT_COMMAND//;;/;}"
PROMPT_COMMAND="${PROMPT_COMMAND#;}"
PROMPT_COMMAND="${PROMPT_COMMAND%;}"
hash -d mise 2>/dev/null || true
HOOK
EOF
    else
        cat > "$dest" << EOF
#!/bin/sh
# mise-uninstall-stub
[ "\${1-}" = "hook-env" ] || { rm -f -- ${dest_q}; exit 127; }
cat <<'HOOK'
unset -f _mise_hook 2>/dev/null || true
PROMPT_COMMAND="\${PROMPT_COMMAND-}"
PROMPT_COMMAND="\${PROMPT_COMMAND//_mise_hook/}"
PROMPT_COMMAND="\${PROMPT_COMMAND//;;/;}"
PROMPT_COMMAND="\${PROMPT_COMMAND#;}"
PROMPT_COMMAND="\${PROMPT_COMMAND%;}"
hash -d mise 2>/dev/null || true
HOOK
printf '%s\n' 'rm -f -- ${dest_q}'
EOF
    fi
    chmod 755 "$dest"
    if [[ $EUID -eq 0 && "$dest" != "$SHARED_MISE" && -n "${TARGET_USER:-}" ]]; then
        chown "$TARGET_USER:" "$dest"
    fi
}

remove_shared_binary() {
    require_root
    remove_path "$SHARED_MISE"
}

remove_system_wide() {
    require_root
    require_profile_d_dir
    if [[ -f "$PROFILE_D_FILE" ]]; then
        rm -f "$PROFILE_D_FILE"
        log "Removed $PROFILE_D_FILE"
        log "Changes take effect in new login sessions."
    fi
}

write_system_wide() {
    require_root
    require_profile_d_dir

    if [[ ! -x "$SHARED_MISE" ]]; then
        err "mise is not installed at ${SHARED_MISE}. Run: sudo $0 system-wide"
    fi

    if [[ -f "$PROFILE_D_FILE" ]]; then
        if grep -qF "$SHIM_LINE" "$PROFILE_D_FILE" && grep -qF "$ACTIVATE_LINE" "$PROFILE_D_FILE"; then
            log "$PROFILE_D_FILE already exists with correct content. Nothing to do."
            return 0
        fi
        if [[ -t 0 ]]; then
            echo ""
            echo "Existing $PROFILE_D_FILE has different content."
            read -rp "Overwrite? [y/N]: " CONFIRM
            if [[ ! "${CONFIRM}" =~ ^[Yy]$ ]]; then
                log "Skipping. Existing configuration preserved."
                return 0
            fi
        else
            err "Non-interactive mode and $PROFILE_D_FILE differs. Use: sudo $0 system-wide --remove"
        fi
    fi

    log "Creating $PROFILE_D_FILE..."
    cat > "$PROFILE_D_FILE" << 'MISEEOF'
# /etc/profile.d/mise.sh — System-wide mise configuration
#
# Adds mise shims to PATH and activates mise for all users.
# This file is sourced by all Bourne-compatible login shells.
# The shared binary lives at /usr/local/bin/mise (Debian default PATH).

# Add mise shims to PATH for all users
export PATH="${HOME}/.local/share/mise/shims:${PATH}"

# Activate mise (enables completions and aliases)
if command -v mise &>/dev/null; then
    eval "$(mise activate bash)"
fi
MISEEOF
    chmod 644 "$PROFILE_D_FILE"
    log "Wrote $PROFILE_D_FILE (new login sessions pick it up)."
}

install_host_pins() {
    log "Installing host pins from ${REPO_ROOT}/mise.host.toml..."
    run_mise_host install
    run_mise_host exec -- yq --version >/dev/null \
        || err "mise is installed but yq is not available. Check ${REPO_ROOT}/mise.host.toml and re-run: $0 install"

    local version
    version="$(run_as_target 'mise --version' | head -n1 | tr -d '\r')"
    log "Ready: ${version} (user ${TARGET_USER})"
}

cmd_install() {
    resolve_target_user
    resolve_repo_root

    if [[ "$FLAG_SYSTEM_WIDE" == true ]]; then
        require_root
        require_profile_d_dir
        install_shared_binary
    else
        install_user_binary
    fi

    install_host_pins

    if [[ "$FLAG_SYSTEM_WIDE" == true ]]; then
        write_system_wide
    fi
}

cmd_system_wide() {
    if [[ "$FLAG_REMOVE" == true ]]; then
        remove_system_wide
        return 0
    fi
    install_shared_binary
    write_system_wide
}

cmd_uninstall() {
    resolve_target_user

    local user_mise had_user_bin had_shared_bin
    user_mise="${TARGET_HOME}/.local/bin/mise"
    had_user_bin=false
    had_shared_bin=false
    [[ -e "$user_mise" || -L "$user_mise" ]] && ! is_uninstall_stub "$user_mise" && had_user_bin=true
    [[ -e "$SHARED_MISE" || -L "$SHARED_MISE" ]] && ! is_uninstall_stub "$SHARED_MISE" && had_shared_bin=true

    if find_mise >/dev/null; then
        log "Uninstalling mise tools for ${TARGET_USER}..."
        run_as_target 'mise uninstall --all' || warn "mise uninstall --all failed; continuing."

        local tools line tool
        tools="$(run_as_target 'mise ls -g --no-header' 2>/dev/null || true)"
        while IFS= read -r line; do
            tool="$(awk '{print $1}' <<< "$line")"
            [[ -n "$tool" ]] || continue
            run_as_target "mise unuse -g $(printf '%q' "$tool") --yes" || true
        done <<< "$tools"

        local implode path
        implode="$(run_as_target 'mise implode -n --config' 2>/dev/null || true)"
        while IFS= read -r line; do
            [[ "$line" == rm\ -rf\ * ]] || continue
            path="${line#rm -rf }"
            path="${path#\"}"
            path="${path%\"}"
            [[ -n "$path" ]] || continue
            if [[ "$path" == "$SHARED_MISE" && "$FLAG_SYSTEM_WIDE" != true ]]; then
                warn "Leaving shared binary ${SHARED_MISE} (use uninstall --system-wide to remove it)."
                continue
            fi
            remove_path "$path"
        done <<< "$implode"
    else
        warn "mise binary not found for ${TARGET_USER}; cleaning known paths."
    fi

    local known
    for known in \
        "${TARGET_HOME}/.local/bin/mise" \
        "${TARGET_HOME}/.local/share/mise" \
        "${TARGET_HOME}/.config/mise" \
        "${TARGET_HOME}/.cache/mise" \
        "${TARGET_HOME}/.local/state/mise"
    do
        remove_path "$known"
    done

    local bashrc="${TARGET_HOME}/.bashrc"
    if [[ -f "$bashrc" ]] && grep -q 'mise activate' "$bashrc"; then
        sed -i.bak '/mise activate/d' "$bashrc"
        log "Removed mise activate from ${bashrc} (backup: ${bashrc}.bak)"
    fi

    if [[ "$FLAG_SYSTEM_WIDE" == true ]]; then
        remove_system_wide
        remove_shared_binary
    fi

    if [[ "$had_user_bin" == true ]]; then
        plant_hook_stub "$user_mise"
    fi
    if [[ "$FLAG_SYSTEM_WIDE" == true && "$had_shared_bin" == true ]]; then
        plant_hook_stub "$SHARED_MISE"
    fi

    log "mise removed for ${TARGET_USER}."
    if [[ "$FLAG_SYSTEM_WIDE" != true ]]; then
        if [[ -f "$PROFILE_D_FILE" ]]; then
            warn "$PROFILE_D_FILE is still present. Remove it with: sudo $0 system-wide --remove"
        fi
        if [[ (-e "$SHARED_MISE" || -L "$SHARED_MISE") ]] && ! is_uninstall_stub "$SHARED_MISE"; then
            warn "${SHARED_MISE} is still present. Remove it with: sudo $0 uninstall --system-wide"
        fi
    fi
}

# ──────────────────────
# Parse arguments
# ──────────────────────
if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        install|system-wide|uninstall)
            [[ -z "$CMD" ]] || err "Only one command is allowed. Use --help for usage."
            CMD="$1"
            shift
            ;;
        --system-wide)
            FLAG_SYSTEM_WIDE=true
            shift
            ;;
        --remove)
            FLAG_REMOVE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            err "Unknown option: $1. Use --help for usage."
            ;;
    esac
done

[[ -n "$CMD" ]] || err "Missing command. Use --help for usage."

if [[ "$FLAG_REMOVE" == true && "$CMD" != "system-wide" ]]; then
    err "--remove is only valid with: system-wide"
fi
if [[ "$FLAG_SYSTEM_WIDE" == true && "$CMD" != "install" && "$CMD" != "uninstall" ]]; then
    err "--system-wide is only valid with: install or uninstall"
fi

case "$CMD" in
    install)      cmd_install ;;
    system-wide)  cmd_system_wide ;;
    uninstall)    cmd_uninstall ;;
esac
