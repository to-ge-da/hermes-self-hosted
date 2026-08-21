# Shared FIGlet HERMES banner for install scripts.
# Sourced by bootstrap.sh and hardening.sh (no figlet runtime dependency).

# shellcheck shell=bash

GREEN="${GREEN:-$'\033[0;32m'}"
CYAN="${CYAN:-$'\033[0;36m'}"
NC="${NC:-$'\033[0m'}"

print_hermes_banner() {
    local subtitle="${1:-}"
    printf '\n%s' "$GREEN"
    cat <<'EOF'
    __  ____________  __  ______________
   / / / / ____/ __ \/  |/  / ____/ ___/
  / /_/ / __/ / /_/ / /|_/ / __/  \__ \
 / __  / /___/ _, _/ /  / / /___ ___/ /
/_/ /_/_____/_/ |_/_/  /_/_____//____/
EOF
    printf '%s' "$NC"
    if [[ -n "$subtitle" ]]; then
        printf '%s%s%s\n\n' "$CYAN" "$subtitle" "$NC"
    else
        printf '\n'
    fi
}
