#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'EOF'
Usage: uninstall-mise.sh [OPTIONS]

Completely remove mise and all its tools.

Options:
  -h, --help    Show this help

Steps:
  1. mise uninstall --all                   — remove all installed tool versions
  2. mise unuse -g <each> --yes             — remove all tools from global config
  3. mise implode -n --config (dry-run)     — capture paths to delete
  4. rm -rf captured paths                  — delete mise binary + data + config + cache + state
  5. sed -i.bak ~/.bashrc                   — remove eval "$(mise activate bash)" (with backup)
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  show_help
  exit 0
fi

if ! command -v mise &>/dev/null; then
  echo "mise is not installed. Nothing to remove."
  exit 1
fi

MISE_BIN=$(command -v mise)
SUDO=""
if [[ "$MISE_BIN" == "/usr/local/bin/mise" || "$MISE_BIN" == "/usr/bin/mise" ]]; then
  SUDO="sudo"
  sudo -v
fi

# --- Part 1: Remove all tools ---

echo "==> Step 1: Uninstalling all tool versions..."
mise uninstall --all

echo "==> Step 2: Removing tools from global config..."
MISE_TOOLS=$(mise ls -g --no-header | awk '{print $1}')
for tool in $MISE_TOOLS; do
  mise unuse -g "$tool" --yes
done

# --- Part 2: Remove mise itself ---

echo "==> Step 3: Capturing mise paths to delete..."
IMPLODE_PATHS=$(mise implode -n --config | sed 's/^rm -rf //')

echo "==> Step 4: Removing mise directories and binary..."
echo "$IMPLODE_PATHS" | $SUDO xargs -I {} rm -rf "{}"

echo "==> Step 5: Removing mise activation from ~/.bashrc (backup saved as ~/.bashrc.bak)..."
sed -i.bak '/mise activate/d' ~/.bashrc

echo "==> Done. mise has been completely removed."
